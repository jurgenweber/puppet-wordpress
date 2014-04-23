define wordpress::app (
  $install_dir          = '/opt/wordpress',
  $install_url          = 'http://wordpress.org',
  $version              = '3.9',
  $create_db            = true,
  $create_db_user       = true,
  $db_name              = 'wordpress',
  $db_host              = 'localhost',
  $db_user              = 'wordpress',
  $db_password          = 'password',
  $wp_owner             = 'root',
  $wp_group             = '0',
  $wp_lang              = '',
  $wp_plugin_dir        = 'DEFAULT',
  $wp_additional_config = 'DEFAULT',
  $wp_table_prefix      = 'wp_',
  $wp_proxy_host        = '',
  $wp_proxy_port        = '',
  $wp_multisite         = false,
  $wp_site_domain       = '',
) {
  validate_string($install_dir,$install_url,$version,$db_name,$db_host,$db_user,$db_password,$wp_owner,$wp_group, $wp_lang, $wp_plugin_dir,$wp_additional_config,$wp_table_prefix,$wp_proxy_host,$wp_proxy_port,$wp_site_domain)
  validate_bool($wp_multisite)
  validate_absolute_path($install_dir)

  if $wp_multisite and ! $wp_site_domain {
    fail('wordpress class requires `wp_site_domain` parameter when `wp_multisite` is true')
  }

  ## Resource defaults
  File {
    owner  => $wp_owner,
    group  => $wp_group,
    mode   => '0644',
  }

  ## Installation directory
  if ! defined(File[$install_dir]) {
    file { $install_dir:
      ensure  => directory,
      recurse => true,
    }
  } else {
    notice("Warning: cannot manage the permissions of ${install_dir}, as another resource (perhaps apache::vhost?) is managing it.")
  }

  ## Download and extract
  exec { "Download wordpress ${wp_site_domain}":
    command     => "wget ${install_url}/wordpress-${version}.tar.gz",
    creates     => "${install_dir}/wordpress-${version}.tar.gz",
    require     => File[$install_dir],
    path        => ['/bin','/sbin','/usr/bin','/usr/sbin'],
    cwd         => $install_dir,
    logoutput   => 'on_failure',
    user        => $wp_owner,
    group       => $wp_group,
  }
  -> exec { "Extract wordpress ${wp_site_domain}":
    command     => "tar zxvf ./wordpress-${version}.tar.gz --strip-components=1",
    creates     => "${install_dir}/index.php",
    path        => ['/bin','/sbin','/usr/bin','/usr/sbin'],
    cwd         => $install_dir,
    logoutput   => 'on_failure',
    user        => $wp_owner,
    group       => $wp_group,
  }
  ~> exec { "Change ownership ${wp_site_domain}":
    command     => "chown -R ${wp_owner}:${wp_group} ${install_dir}",
    refreshonly => true,
    path        => ['/bin','/sbin','/usr/bin','/usr/sbin'],
    cwd         => $install_dir,
    logoutput   => 'on_failure',
    user        => $wp_owner,
    group       => $wp_group,
  }

  ## Configure wordpress
  #
  # Template uses no variables
  file { "${install_dir}/wp-keysalts.php":
    ensure  => present,
    content => template('wordpress/wp-keysalts.php.erb'),
    replace => false,
    require => Exec["Extract wordpress ${wp_site_domain}"],
  }
  concat { "${install_dir}/wp-config.php":
    owner   => $wp_owner,
    group   => $wp_group,
    mode    => '0755',
    require => Exec["Extract wordpress ${wp_site_domain}"],
  }
  concat::fragment { "wp-config.php keysalts ${wp_site_domain}":
    target  => "${install_dir}/wp-config.php",
    source  => "${install_dir}/wp-keysalts.php",
    order   => '10',
    require => File["${install_dir}/wp-keysalts.php"],
  }
  # Template uses: $db_name, $db_user, $db_password, $db_host, $wp_proxy, $wp_proxy_host, $wp_proxy_port, $wp_multisite, $wp_site_domain
  concat::fragment { "wp-config.php body ${wp_site_domain}":
    target  => "${install_dir}/wp-config.php",
    content => template('wordpress/wp-config.php.erb'),
    order   => '20',
  }
}
