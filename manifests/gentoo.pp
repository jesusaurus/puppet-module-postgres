class postgres::gentoo {

  include gentoo

  package {
    "dev-db/postgresql-server":
      ensure => present,
      alias  => 'postgresql',
  }

  exec {
    "config-postsgresql-server":
      command => "emerge --config dev-db/postgresql",
      require => Package['dev-db/postgresql-server'],
  }

}
