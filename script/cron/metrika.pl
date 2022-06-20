#!/usr/bin/env perl

use Modern::Perl;
use utf8;

use Data::Dumper;
use DBI;
use YAML::Tiny;
use Proc::PID::File;
use Getopt::Long;
use Try::Tiny;
use Log::Log4perl;
use LWP::UserAgent;
use JSON::XS;

use lib '/www/api_checker/lib';
use ApiChecker::Core::IP;
use ApiChecker::Core::Utils;

use Yandex::Metrika;

my $all_appenders  = YAML::Tiny->read( '/www/api_checker/config/log4perl.conf.yaml' )->[0]->{log4perl_appenders};
my $all_categories = YAML::Tiny->read( '/www/api_checker/config/log4perl.conf.yaml' )->[0]->{log4perl_categories};
my $config         = { %$all_appenders, %$all_categories };


# Log::Log4perl->init($config);

# my $log = Log::Log4perl->get_logger('metrika');

my $conf = YAML::Tiny->read( '/www/api_checker/config/connect.yaml' )->[0];
my $dbh = DBI->connect($conf->{dsn}, $conf->{username}, $conf->{password}, {
      PrintError => 1,
      AutoCommit => 1,
      'RaiseError' => 1,
      'mysql_enable_utf8' => 1,
});

# $log->info("Start get data from ts3");

my $ip = ApiChecker::Core::IP->new( $dbh );

my @date = ApiChecker::Core::Utils::mysqldate_decode( ApiChecker::Core::Utils::today_mydate() );

$ip->get_metrika_user_vars({ data1 => $date[0].$date[1].$date[2], data2 => $date[0].$date[1].$date[2] });
