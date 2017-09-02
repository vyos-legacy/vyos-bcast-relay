cfgdir = $(datadir)/vyatta-cfg/templates
curverdir = $(sysconfdir)/config-migrate/current
bin_sudo_usersdir = $(bindir)/sudo-users

vprefix = /opt/vyatta
vsbindir = $(vprefix)/sbin

sbin_SCRIPTS = scripts/ubnt-bcast-relay.pl

sbin_PROGRAMS = src/udp-bcast-relay
src_udp_bcast_relay_SOURCES = src/main.c

cpiop = find  . ! -regex '\(.*~\|.*\.bak\|.*\.swp\|.*\#.*\#\)' -print0 | \
  cpio -0pd

install-exec-hook:
	mkdir -p $(DESTDIR)$(cfgdir)
	cd templates-cfg; $(cpiop) $(DESTDIR)$(cfgdir)
