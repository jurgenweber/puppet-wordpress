#
#
#
define wordpress::db (
  $create_db            = true,
  $create_db_user       = true,
  $db_name              = 'wordpress',
  $db_host              = 'localhost',
  $db_user              = 'wordpress',
  $db_password          = 'password',
) {
  validate_bool($create_db,$create_db_user)
  validate_string($db_name,$db_host,$db_user,$db_password)

  ## Set up DB using puppetlabs-mysql defined type
  if $create_db {
    mysql_database { $db_name:
      charset       => 'utf8',
      require       => Wordpress::App[$name],
    }
  }
  if $create_db_user {
    mysql_user { "${db_user}@${db_host}":
      password_hash => mysql_password($db_password),
      require       => Wordpress::App[$name],
    }
    mysql_grant { "${db_user}@${db_host}/${db_name}.*":
      table         => "${db_name}.*",
      user          => "${db_user}@${db_host}",
      privileges    => ['ALL'],
      require       => Wordpress::App[$name],
    }
  }

}
