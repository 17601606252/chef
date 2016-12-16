#!/usr/bin/env python3
# vim: tabstop=8 expandtab shiftwidth=4 softtabstop=4

import sys
import dnf
import hawkey
import signal
import os
import json

base = None

def get_sack():
    global base
    if base is None:
        base = dnf.Base()
        base.read_all_repos()
        base.fill_sack()
    return base.sack

# FIXME: leaks memory and does not work
def flushcache():
    try:
        os.remove('/var/cache/dnf/@System.solv')
    except OSError:
        pass
    get_sack().load_system_repo(build_cache=True)

def get_pkgspec(command):
    sack = get_sack()

    subj = dnf.subject.Subject(command['provides'])
    q = subj.get_best_query(sack, with_provides=True)

    if command['action'] == "whatinstalled":
        q = q.installed()

    if command['action'] == "whatavailable":
        q = q.available()

    if 'epoch' in command:
        q = q.filterm(epoch=int(command['epoch']))
    if 'version' in command:
        q = q.filterm(version__glob=command['version'])
    if 'release' in command:
        q = q.filterm(release__glob=command['release'])

    if 'arch' in command:
        q = q.filterm(arch__glob=command['arch'])

    # only apply the default arch query filter if it returns something
    archq = q.filter(arch=[ 'noarch', hawkey.detect_arch() ])
    if len(archq.run()) > 0:
        q = archq

    pkgs = dnf.query.latest_limit_pkgs(q, 1)

    if not pkgs:
        return None

    # make sure we picked the package with the highest version
    pkgs.sort
    return pkgs.pop()

def query(command):
    pkg_spec = get_pkgspec(command)

    if pkg_spec is None:
        sys.stdout.write('{} nil nil\n'.format(command['provides'].split().pop(0)))
    else:
        sys.stdout.write('{} {}:{}-{} {}\n'.format(pkg_spec.name, pkg_spec.epoch, pkg_spec.version, pkg_spec.release, pkg_spec.arch))

def install(command):
    command['action'] = "whatavailable"
    pkg_spec = get_pkgspec(command)
    if pkg_spec is None:
        raise RuntimeError("no available package")

    sys.stderr.write('FOO1')
    base.package_install(pkg_spec)
    sys.stderr.write('FOO2')

    base.resolve()
    sys.stderr.write('FOO3')

    base.download_packages(base.transaction.install_set)
    sys.stderr.write('FOO4')

    base.do_transaction()
    sys.stderr.write('FOO5')
    sys.stdout.write('{} {}:{}-{} {}\n'.format(pkg_spec.name, pkg_spec.epoch, pkg_spec.version, pkg_spec.release, pkg_spec.arch))

# the design of this helper is that it should try to be 'brittle' and fail hard and exit in order
# to keep process tables clean.  additional error handling should probably be added to the retry loop
# on the ruby side.
def exit_handler(signal, frame):
    sys.exit(0)

signal.signal(signal.SIGINT, exit_handler)
signal.signal(signal.SIGHUP, exit_handler)
signal.signal(signal.SIGPIPE, exit_handler)
signal.signal(signal.SIGCHLD, exit_handler)

while 1:
    # kill self if we get orphaned (tragic)
    ppid = os.getppid()
    if ppid == 1:
        sys.exit(0)
    line = sys.stdin.readline()
    command = json.loads(line)
    if command['action'] == "whatinstalled":
        query(command)
    elif command['action'] == "whatavailable":
        query(command)
    elif command['action'] == "install":
        install(command)
    elif command['action'] == "flushcache":
        flushcache()
    else:
        raise RuntimeError("bad command")
