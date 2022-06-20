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

my $all_appenders  = YAML::Tiny->read( '/www/api_checker/config/log4perl.conf.yaml' )->[0]->{log4perl_appenders};
my $all_categories = YAML::Tiny->read( '/www/api_checker/config/log4perl.conf.yaml' )->[0]->{log4perl_categories};
my $config         = { %$all_appenders, %$all_categories };


Log::Log4perl->init($config);

my $log = Log::Log4perl->get_logger('ts3');

my $conf = YAML::Tiny->read( '/www/api_checker/config/connect.yaml' )->[0];
my $dbh = DBI->connect($conf->{dsn}, $conf->{username}, $conf->{password}, {
      PrintError => 1,
      AutoCommit => 1,
      'RaiseError' => 1,
      'mysql_enable_utf8' => 1,
});

$log->info("Start get data from ts3");

my $ip = ApiChecker::Core::IP->new( $dbh );

my $ts3_answer;

eval {         
    $ts3_answer = $ip->download_ts3_data(); # $ip->read_content("/Users/chips/work/chips/ts3ip.json");
};

if ( @! ) {
    $log->error("Failed download ts3 data\n" . Dumper(\@_) );
    die();
}
        
$ip->update_ts3_users($ts3_answer);
$ip->update_ts3_users_ip($ts3_answer);

$log->info("End get data from ts3");
