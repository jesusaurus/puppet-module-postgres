class postgres (
  user = 'postgres',
) {

  user {
    "$user" :
      ensure => present,
  }

  $data_dir = $postgresql_data_dir ? {
    "" => "/var/lib/postgresql",
    default => $postgresql_data_dir,
  }

  case $operatingsystem {
    'Ubuntu': {
      include postgres::ubuntu
    }

    'Gentoo': {
      include postgres::gentoo
    }

    default: {
      fail "postgresql not available for ${operatingsystem}"
    }
  }


}


/*

==Definition: postgresql::database

Create a new PostgreSQL database

*/
define postgres::database(
  $ensure=present,
  $owner=false,
  $encoding=false,
  $template="template1",
  $source=false,
  $overwrite=false) {

  $ownerstring = $owner ? {
    false => "",
    default => "-O $owner"
  }

  $encodingstring = $encoding ? {
    false => "",
    default => "-E $encoding",
  }

  case $ensure {
    present: {
      exec { "Create $name postgres db":
        command => "/usr/bin/createdb $ownerstring $encodingstring $name -T $template",
        user    => "postgres",
        unless  => "test \$(psql -tA -c \"SELECT count(*)=1 FROM pg_catalog.pg_database where datname='${name}';\") = t",
        require => Package["postgresql"],
      }
    }
    absent:  {
      exec { "Remove $name postgres db":
        command => "/usr/bin/dropdb $name",
        user    => "postgres",
        onlyif  => "test \$(psql -tA -c \"SELECT count(*)=1 FROM pg_catalog.pg_database where datname='${name}';\") = t",
        require => Package["postgresql"],
      }
    }
    default: {
      fail "Invalid 'ensure' value '$ensure' for postgres::database"
    }
  }

  # Drop database before import
  if $overwrite {
    exec { "Drop database $name before import":
      command => "dropdb ${name}",
      onlyif  => "/usr/bin/psql -l | grep '$name  *|'",
      user    => "postgres",
      before  => Exec["Create $name postgres db"],
      require => Package["postgresql"],
    }
  }

  # Import initial dump
  if $source {
    # TODO: handle non-gziped files
    exec { "Import dump into $name postgres db":
      command => "zcat ${source} | psql ${name}",
      user => "postgres",
      onlyif => "test $(psql ${name} -c '\\dt' | wc -l) -eq 1",
      require => Exec["Create $name postgres db"],
    }
  }
}


/*

==Definition: postgresql::user

Create a new PostgreSQL user

*/
define postgres::user(
  $ensure=present,
  $password=false,
  $superuser=false,
  $createdb=false,
  $createrole=false,
  $hostname='/var/run/postgresql',
  $port='5432',
  $user='postgres') {

  $pgpass = $password ? {
    false   => "",
    default => "$password",
  }

  $superusertext = $superuser ? {
    false   => "NOSUPERUSER",
    default => "SUPERUSER",
  }

  $createdbtext = $createdb ? {
    false   => "NOCREATEDB",
    default => "CREATEDB",
  }

  $createroletext = $createrole ? {
    false   => "NOCREATEROLE",
    default => "CREATEROLE",
  }

  # Connection string
  $connection = "-h ${hostname} -p ${port} -U ${user}"

  case $ensure {
    present: {

      # The createuser command always prompts for the password.
      # User with '-' like www-data must be inside double quotes
      exec { "Create postgres user $name":
        command => $password ? {
          false => "psql ${connection} -c \"CREATE USER \\\"$name\\\" \" ",
          default => "psql ${connection} -c \"CREATE USER \\\"$name\\\" PASSWORD '$password'\" ",
        },
        user    => "postgres",
        require => [
          User["postgres"],
          Package["postgresql"],
        ],
      }

      exec { "Set SUPERUSER attribute for postgres user $name":
        command => "psql ${connection} -c 'ALTER USER \"$name\" $superusertext' ",
        user    => "postgres",
        require => [User["postgres"], Exec["Create postgres user $name"]],
      }

      exec { "Set CREATEDB attribute for postgres user $name":
        command => "psql ${connection} -c 'ALTER USER \"$name\" $createdbtext' ",
        user    => "postgres",
        require => [User["postgres"], Exec["Create postgres user $name"]],
      }

      exec { "Set CREATEROLE attribute for postgres user $name":
        command => "psql ${connection} -c 'ALTER USER \"$name\" $createroletext' ",
        user    => "postgres",
        require => [User["postgres"], Exec["Create postgres user $name"]],
      }

      if $password {
        $host = $hostname ? {
          '/var/run/postgresql' => "localhost",
          default               => $hostname,
        }

        # change only if it's not the same password
        exec { "Change password for postgres user $name":
          command => "psql ${connection} -c \"ALTER USER \\\"$name\\\" PASSWORD '$password' \"",
          user    => "postgres",
          unless  => "test $(TMPFILE=$(mktemp /tmp/.pgpass.XXXXXX) && echo '${host}:${port}:template1:${name}:${pgpass}' > \$TMPFILE && PGPASSFILE=\$TMPFILE psql -h ${host} -p ${port} -U ${name} -c '\\q' template1 && rm -f \$TMPFILE)",
          require => [User["postgres"], Exec["Create postgres user $name"]],
        }
      }

    }

    absent:  {
      exec { "Remove postgres user $name":
        command => "psql ${connection} -c 'DROP USER \"$name\" ' ",
        user    => "postgres",
        onlyif  => "psql ${connection} -c '\\du' | grep '$name  *|'",
        require => Package["postgresql"],
      }
    }

    default: {
      fail "Invalid 'ensure' value '$ensure' for postgres::user"
    }
  }
}
