class nasbox {
    require nasbox::check
    require nasbox::base

	include nasbox::users
	include nasbox::samba
	include nasbox::drives

}

class nasbox::check {

	if ($operatingsystem != "Ubuntu") {
		fail ("FAILING: Operating System $operatingsystem is not yet supported, wanna help out?")
	}
}

class nasbox::base {

	$base_packages = [openssh-server, sysstat, xfsprogs, hdparm, smartmontools, screen, iptraf, git, whois ]
	
	install_unless_defined { $base_packages: }

	define install_unless_defined {
		if ( ! defined(Package[$name]) ) {
			package { $name:
				ensure => present,
			}
		}
	}
}

class nasbox::drives {

	$drive_utils = [hdparm, smartmontools ]
	$hdparm_spindown = get_var("nasbox","hdparm.spindown","240")
	
	package { $drive_utils:
		ensure => present,
	}

	file { '/etc/hdparm.conf':
		ensure => file,
		mode => 644,
		content => template("nasbox/drives/hdparm.conf.erb"),
	}
}

class nasbox::samba {
	include zeroconf
	include samba::server

	zeroconf::service_config { smb: 
		content => template("nasbox/zeroconf/smb.service.erb"),
	}

	$samba_shares = get_var("nasbox","samba.shares")
	samba::server::config { smb: 
		content => template("nasbox/samba/smb.conf.erb"),
	}

	$samba_shares_names = get_var("nasbox","samba.shares.keys")
	create_unless_defined { $samba_shares_names: }

	define create_unless_defined {
		$dir = get_var("nasbox","samba.shares.$name.path")
		if ( ! defined( File[$dir]) ) {
			file { $name:
				ensure => directory,
				path => $dir,
				mode => 777,
				owner => root,
				group => root,
				before => [Samba::Server::Config["smb"]],
				require => Exec["create_parent-$dir"],
			}
			# I should probably use directory module instead, but meh, one more dependency
			exec { "create_parent-$dir":
				command => "/bin/mkdir -p `/usr/bin/dirname $dir`",
				path => "/bin:/usr/bin:/sbin:/usr/sbin",
				onlyif => "test ! -d `/usr/bin/dirname $dir`",
			}
		}
	}

}

class nasbox::users {

	$users = get_var ("nasbox", "users.keys")
	nasbox::users::config { $users: }

	define config {
		user { "$name":
			ensure => present,
			uid => get_var("nasbox", "users.$name.uid"),
			gid => get_var("nasbox", "users.$name.gid"),
			groups => get_var("nasbox", "users.$name.groups"),
			shell => get_var("nasbox", "users.$name.shell", "/bin/true"),
			managehome => true,
			require => Group["$gid"],
		}
		group { "$name":
			ensure => present,
			gid => get_var("nasbox", "users.$name.gid"),
		}
		$pass = get_var("nasbox", "users.$name.password")
		exec { "set_pass-$name":
			command => "/usr/sbin/usermod -p `/usr/bin/mkpasswd -H MD5 $pass` $name",
			path => "/bin:/usr/bin:/sbin:/usr/sbin",
			require => [ User["$name"],  Package["whois"] ],
		}
		exec { "set_samba_pass-$name":
			command => "/bin/echo -e \"$pass\\n$pass\" | /usr/bin/smbpasswd -s -a $name",
			path => "/bin:/usr/bin:/sbin:/usr/sbin",
			require => [ User["$name"], Class["nasbox::samba"] ],
		}
	}
}
