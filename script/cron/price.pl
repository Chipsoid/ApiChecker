#!/usr/bin/env perl

use Modern::Perl;
use utf8;

use Data::Dumper;
use DBI;
use YAML::Tiny;
use Proc::PID::File;
use Getopt::Long;
use Log::Log4perl;

use lib '/www/Games-EveOnline-API/lib';
use Games::EveOnline::API;

use lib '/www/games-eveonline-evecentral/lib';
use Games::EveOnline::EveCentral;
use Games::EveOnline::EveCentral::Request::MarketStat;


use lib '/www/api_checker/lib';
use ApiChecker::Core::Api;
use ApiChecker::Core::Account;
use ApiChecker::Core::Eve;
use ApiChecker::Core::Utils;

my $all_appenders  = YAML::Tiny->read( '/www/api_checker/config/log4perl.conf.yaml' )->[0]->{log4perl_appenders};
my $all_categories = YAML::Tiny->read( '/www/api_checker/config/log4perl.conf.yaml' )->[0]->{log4perl_categories};
my $config         = { %$all_appenders, %$all_categories };


Log::Log4perl->init($config);

my %opt = ();
my $for_id;
GetOptions(
    \%opt,
    qw/
        help|h

        debug|d
        verbose|v+
    /,
    "id=i" => \$for_id,
) or die;

if ( my $pid = Proc::PID::File->running({dir=>'/www/api_checker/log/', verify=>1}) ) {
    print  'Already running, pid='.$pid;
    exit 1;
}

my $log = Log::Log4perl->get_logger('price_cron');

my $conf = YAML::Tiny->read( '/www/api_checker/config/connect.yaml' )->[0];
my $dbh = DBI->connect($conf->{dsn}, $conf->{username}, $conf->{password}, {
      PrintError => 1,
      AutoCommit => 1,
      'RaiseError' => 1,
      'mysql_enable_utf8' => 1,
});

$log->info( 'Start update prices' );
my $api = ApiChecker::Core::Api->new( $dbh );
my $eve = ApiChecker::Core::Eve->new( $dbh, $api );
$eve->update_eve_prices();
$log->info( 'Finish update prices' );


# $dbh->do("TRUNCATE TABLE eve_central_prices;");
# no warnings 'recursion';
# $eve->update_prices();

# $log->info( 'Finish update prices' );
