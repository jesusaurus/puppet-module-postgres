class postgres::gentoo {

  package {
    'dev-db/postgresql-server':
      ensure    => present,
      name      => 'postgresql-server',
      category  => 'dev-db',
      alias     => 'postgresql',
  }

  exec {
    "config-postsgresql-server":
      command => "/usr/bin/emerge --config dev-db/postgresql",
      require => Package['dev-db/postgresql-server'],
  }

}
