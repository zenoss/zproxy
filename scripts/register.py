import argparse
import subprocess
import sys
import os


def handleRegister(args):
    # handleLoadScripts(args, printOutput=False)
    print "Registering %s -> %s" % (args.frontend, args.backend)
    print register(args.frontend, args.backend, args.host, args.port)


def handleUnregister(args):
    # handleLoadScripts(args, printOutput=False)
    print "Unregistering %s -> %s" % (args.frontend, args.backend)
    print unregister(args.frontend, args.backend, args.host, args.port)


def handleFile(args):
    proxied = []
    host = args.host
    port = args.port
    # handleLoadScripts(args, printOutput=False)
    with open(args.file, "r") as file:
        for line in file:
            line = line.strip()
            if line.startswith("host "):
                host = line.split()[1]
            if line.startswith("port "):
                port = line.split()[1]
            elif line and not line.startswith('#'):
                proxied.append(line.split())
    for frontend, backend in proxied:
        register(frontend, backend, host, port)


def handleLoadScripts(args, printOutput=True):
    check_redis_cli()
    if printOutput:
        print "Loading scripts..."
    home = os.environ['HIPACHE_HOME']
    load_script(args.host, args.port, "register", "%s/scripts/register.lua" % home)
    load_script(args.host, args.port, "unregister", "%s/scripts/unregister.lua" % home)


def handleList(args):
    check_redis_cli()
    if not args.frontend:
        print redis_cli(args.host, args.port, "keys", "frontend:*")
    else:
        frontend = args.frontend[0]
        print "Backends for %s:" % frontend
        print redis_cli(args.host, args.port, "lrange", "frontend:%s" % frontend, 1, -1)


def register(frontend, backend, redisHost, redisPort):
    check_redis_cli()
    output = redis_cli(redisHost, redisPort, 'hget', 'scripts', 'register')
    if output is None or not output.strip():
        print >> sys.stderr, "Error finding redis script. %s" % output
        sys.exit(1)

    output = redis_cli(redisHost, redisPort, 'evalsha', output, '1', frontend, backend)
    return output


def unregister(frontend, backend, redisHost, redisPort):
    subprocess.call(['which', 'redis-cli'])
    output = redis_cli(redisHost, redisPort, 'hget', 'scripts', 'unregister')
    if output is None or not output.strip():
        print >> sys.stderr, "Error finding redis script. %s" % output
        sys.exit(1)

    output = redis_cli(redisHost, redisPort, 'evalsha', output, '1', frontend, backend)
    return output


def redis_cli(host, port, *args):
    cmd = ['redis-cli', "-h", host, '-p', str(port)]
    cmd.extend(map(str, args))
    # print " ".join(cmd)
    output = subprocess.check_output(cmd).strip()
    if output and output.strip().startswith("ERR"):
        print >> sys.stderr, "Error: %s" % output
        sys.exit(1)
    return output


def check_redis_cli():
    subprocess.check_output(['which', 'redis-cli'])


def load_script(host, port, name, path):
    if not os.path.isfile(path):
        print >> sys.STDERR, "File not found %s" % path
        exit(1)

    with open(path, "r") as scriptFile:
        scriptLines = scriptFile.readlines()
        script = "\n".join(scriptLines)
        hash = redis_cli(host, port, "script", "load", script)
        redis_cli(host, port, "hset", "scripts", name, hash)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(prog='register', description='Utility to register service endpoints in redis')
    parser.add_argument("--host", default='localhost')
    parser.add_argument("--port", type=int, default=6379)

    subparsers = parser.add_subparsers()

    parser_register = subparsers.add_parser('add', help='Register a single service endpoint in redis')
    parser_register.set_defaults(func=handleRegister)
    parser_register.add_argument('frontend', help="The path that will be proxied to a backend")
    parser_register.add_argument('backend', help='The backend to which a request will be sent')

    parser_register = subparsers.add_parser('remove', help='Unegister a single service endpoint in redis')
    parser_register.set_defaults(func=handleUnregister)
    parser_register.add_argument('frontend', help="The path that will be proxied to a backend")
    parser_register.add_argument('backend', help='The backend to which a request will be sent')

    parser_register = subparsers.add_parser('from-file', help='Register service endpoints from a file')
    parser_register.set_defaults(func=handleFile)
    parser_register.add_argument('file', help="File that contains service endpoints")

    parser_register = subparsers.add_parser('load-scripts', help='Load the utility scripts for registering and '
                                                                 'un-registering services into redis')
    parser_register.set_defaults(func=handleLoadScripts)

    parser_register = subparsers.add_parser('list', help='List registered endpoints')
    parser_register.add_argument('frontend', nargs="*",
                                 help="List the backends for a given frontend, if empty lists all frontends")
    parser_register.set_defaults(func=handleList)

    args = parser.parse_args()
    args.func(args)

