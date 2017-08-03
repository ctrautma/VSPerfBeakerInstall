"""
NSConnect.py

Net Scout simple CLI script to connect and disconnect ports based on their
port names. After single execution will store connection and login info into
a settings file that is not secure. It is encoded to provide minimal security.

This module can be added to provide much more functionality as requested.

Execute NetScout command

optional arguments:
  -h, --help            show this help message and exit
  --connect port1 port2
                        Create a connection between two ports
  --disconnect port [port ...]
                        Disconnect a port(s) from its connection

Copyright 2016 Christian Trautman ctrautma@redhat.com

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as
    published by the Free Software Foundation, either version 3 of the
    License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
"""

import argparse
import base64
import configparser
import locale
import telnetliblog
from time import sleep

_LOCALE = locale.getlocale()[1]


class NetScout_Command(object):
    def __init__(self, parser, args):
        self.args = args
        if not any([args.connect,
                    args.disconnect,
                    args.listports,
                    args.listgroups,
                    args.portinfo]):
            print("No actions provided...")
            import sys
            parser.print_help()
            sys.exit(1)

        self._cfg = configparser.ConfigParser()
        print("Checking for config file...")
        self._cfg.read('settings.cfg')

        try:
            self._ip_addr = base64.b64decode(
                self._cfg['INFO']['host']).decode(_LOCALE)
            self._port = base64.b64decode(
                self._cfg['INFO']['port']).decode(_LOCALE)
            self._username = base64.b64decode(
                self._cfg['INFO']['username']).decode(_LOCALE)
            self._password = base64.b64decode(
                self._cfg['INFO']['password']).decode(_LOCALE)
            print("Config file found and read...")
        except KeyError:
            self.write_settings()

        print("Connecting to Netscout at {}".format(self._ip_addr))
        self.tn = telnetliblog.Telnet2(self._ip_addr, self._port)

        self.logon()

        self.parse_args()

    def connect(self, ports):
        self.issue_command('connect PORT {} to PORT {} force'.format(*ports))

    def disconnect(self, ports):
        for port in ports:
            self.issue_command('connect PORT {} to null force'.format(port))

    def issue_command(self, cmd, timeout=30):
        self.tn.write('{}\r'.format(cmd).encode(_LOCALE))
        out = self.tn.expect(['=\>'.encode(_LOCALE)], timeout=timeout)
        if out[0] != -1:
            return True
        else:
            return False

    def get_command_output(self, cmd, timeout=30):
        self.tn.write('{}\r'.format(cmd).encode(_LOCALE))
        out = self.tn.expect(['=\>'.encode(_LOCALE)], timeout=timeout)
        if out[0] != -1:
            return out[2]
        else:
            return ''

    def list_groups(self):
        out = self.get_command_output('show groups', timeout=60)
        out = out.decode(_LOCALE).split('\r\n')
        for line in out[2:-2]:
            print(line)

    def list_ports(self):
        out = self.get_command_output('show ports', timeout=60)
        out = out.decode(_LOCALE).split('\r\n')
        for line in out[2:-2]:
            print(line)

    def logon(self):
        print("Attempting to logon to Netscout...")
        self.tn.write('\r'.encode(_LOCALE))
        out = self.tn.expect(['=\>'.encode(_LOCALE)], timeout=30)
        if out[0] != -1:
            self.tn.write('logon {}\r'.format(self._username).encode(_LOCALE))
        else:
            raise RuntimeError('Failed to get basic prompt on telnet!!!')
        out = self.tn.expect(['Password:'.encode(_LOCALE)], timeout=30)
        sleep(1)
        if out[0] != -1:
            self.tn.write('{}\r'.format(self._password).encode(_LOCALE))
        else:
            raise RuntimeError('Did not get password prompt!!!')
        out = self.tn.expect(['=\>'.encode(_LOCALE)], timeout=30)
        if out[0] == -1:
            raise RuntimeError('Failed to logon!!!')

    def parse_args(self):
        if self.args.connect:
            self.connect(self.args.connect)
        if self.args.disconnect:
            self.disconnect(self.args.disconnect)
        if self.args.listports:
            self.list_ports()
        if self.args.listgroups:
            self.list_groups()
        if self.args.portinfo:
            self.show_port_info(self.args.portinfo)

    def show_port_info(self, ports):
        for port in ports:
            out = self.get_command_output(
                'show information Port {}'.format(port), timeout=60)
            out = out.decode(_LOCALE).split('\r\n')
            for line in out[0:-1]:
                print(line)

    def write_settings(self):
        print("Config file not present....")
        print("Please answer the following questions.")
        self._ip_addr = input("Netscout IP address:")
        self._port = input("Netscout telnet port:")
        self._username = input("Netscout username:")
        from getpass import getpass
        self._password = getpass("Netscout password:")
        self._cfg['INFO'] = {
            'host': base64.b64encode(self._ip_addr.encode(_LOCALE)).decode(),
            'port': base64.b64encode(self._port.encode(_LOCALE)).decode(),
            'username': base64.b64encode(
                self._username.encode(_LOCALE)).decode(),
            'password': base64.b64encode(
                self._password.encode(_LOCALE)).decode()}
        with open('settings.cfg', 'w') as fh:
            self._cfg.write(fh)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Execute NetScout command')

    parser.add_argument('--connect', nargs=2, type=str,
                        help='Create a connection between two ports',
                        required=False, metavar=('port1', 'port2'))
    parser.add_argument('--disconnect', nargs='+', type=str,
                        help='Disconnect a port(s) from its connection',
                        required=False, metavar=('port', 'port'))
    parser.add_argument('--listgroups', action='store_true',
                        help='Show list of available groups', required=False)
    parser.add_argument('--listports', action='store_true',
                        help='Show list of available ports', required=False)
    parser.add_argument('--portinfo', nargs='+', type=str,
                        help='Show information on ports', required=False)
    args = parser.parse_args()
    NETS = NetScout_Command(parser, args)
