# Nagios plugin for checking various parameters on a FreeSWITCH system

`check_freeswitch_health.pl` is a plugin for Nagios that checks various health parameters on a FreeSWITCH server. It takes advantage of the `fs_cli` FreeSWITCH command-line tool. It may be extended to check practically anything that fs_cli can check.

## This Version

This version of the plugin, which exists only on this branch, is for Sangoma NSG devices. 
Thanks to user [richilp](https://github.com/richilp) who submitted this via [issue #4](https://github.com/kjhosein/nagios-freeswitch-plugin/issues/4).

## License

This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.

## Installation/Usage 

`check_freeswitch_health.pl` must be installed in the Nagios plugins directory on the host system (not the Nagios server). It is called via NRPE. 

Sample nrpe.cfg command line:
`command[check_freeswitch_health]=/usr/lib64/nagios/plugins/check_freeswitch_health.pl $ARG1$`

and on the Nagios server, corresponding commands and services may be:
```
  define command {
    command_name    check_freeswitch_health
    command_line    $USER1$/check_nrpe -H $HOSTADDRESS$ -c check_freeswitch_health $ARG1$
  }
```
```
  define service {
    host_name       freeswitch01
    service_description     FreeSWITCH - Calls Count
    check_command   check_freeswitch_health!-a '-q show-calls-count'!!!!!!!
  }
```

## Author

Khalid J Hosein

Written July 2013

## To Do

- [ ] Refine the use of the $perfdatatitle (better logic on selecting the title)
- [ ] First check for the fs_cli command, and report back via cmd line output and perfdata if can't find

## Thanks

Thanks to Ton Voon for his [Nagios::Plugin Perl module](http://search.cpan.org/~tonvoon/Nagios-Plugin-0.36/). It dramatically cuts development time for writing Nagios plugins and keeps the main code clean.

Thanks also to:
* Nathan Vonnahme for his presentation Writing Custom Nagios Plugins In Perl. [Available on SlideShare](http://www.slideshare.net/nagiosinc/nagios-conference-2011-nathan-vonnahme-writing-custom-nagios-plugins-in-perl).
* Jose Luis Martinez for his presentation on Writing Perl Nagios Plugins. [PDF](http://www.pplusdomain.net/Writing%20Nagios%20Plugins%20in%20Perl.pdf)
