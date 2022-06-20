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
use lib '/www/games-eveonline-evecentral/lib';
use Games::EveOnline::API;

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

my $log = Log::Log4perl->get_logger('info_cron');

my $conf = YAML::Tiny->read( '/www/api_checker/config/connect.yaml' )->[0];
my $dbh = DBI->connect($conf->{dsn}, $conf->{username}, $conf->{password}, {
      PrintError => 1,
      AutoCommit => 1,
      'RaiseError' => 1,
      'mysql_enable_utf8' => 1,
});

my $api = ApiChecker::Core::Api->new( $dbh );
my $eve = ApiChecker::Core::Eve->new( $dbh, $api );


my $char_ids = $dbh->selectcol_arrayref("
         SELECT cs.character_id
         FROM  character_sheet cs
         INNER JOIN character_assets ca ON ca.character_id = cs.character_id
         WHERE cs.is_bigboy = 1 OR ca.type_id IN (SELECT typeID FROM eve.invTypes WHERE groupID IN (30,659) )
         GROUP BY cs.character_id;", undef );

$log->info( 'Start update character_info' );
$eve->set_character_info( $char_ids );
$log->info( 'Finish update character_info' );

