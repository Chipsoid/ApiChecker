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

use lib '/www/Games-EveOnline-API/lib';
use Games::EveOnline::API;

use lib '/www/api_checker/lib';
use ApiChecker::Core::Api;
use ApiChecker::Core::Account;
use ApiChecker::Core::Corp;
use ApiChecker::Core::Eve;
use ApiChecker::Core::Utils;

my $all_appenders  = YAML::Tiny->read( '/www/api_checker/config/log4perl.conf.yaml' )->[0]->{log4perl_appenders};
my $all_categories = YAML::Tiny->read( '/www/api_checker/config/log4perl.conf.yaml' )->[0]->{log4perl_categories};
my $config         = { %$all_appenders, %$all_categories };


Log::Log4perl->init($config);

my %opt = ();
my $for_id;
my $only_key;

GetOptions(
    \%opt,
    qw/
        help|h

        debug|d
        verbose|v+
        force|f
    /,
    "key=i" => \$only_key,
    "id=i"  => \$for_id,
) or die;

my %action_for = (
    'update_jobs' => \&update_jobs,
);


if ( $opt{help} ) {
    show_help();
    exit;
}

my $verbose = delete $opt{verbose} || 0;
my $debug   = delete $opt{debug}   || 0;
my $force   = delete $opt{force}   || 0;
delete $opt{id};
delete $opt{key};


my $log = Log::Log4perl->get_logger('industry_cron');

my $conf = YAML::Tiny->read( '/www/api_checker/config/connect.yaml' )->[0];
my $dbh = DBI->connect($conf->{dsn}, $conf->{username}, $conf->{password}, {
      PrintError => 1,
      AutoCommit => 1,
      'RaiseError' => 1,
      'mysql_enable_utf8' => 1,
});

# Выполняем только указанные флагами задания, или все,
# если ни одного флага не указано
my $exec_all_tasks = !grep { $_ } values %opt;

for my $option ( keys %action_for ) {

    if ( $opt{$option} || $exec_all_tasks ) {

        $log->debug("Executing option: '$option'");
        eval {
            $action_for{$option}->();
        };
        if ( $@ ) {
            my $err = $@;

            eval{ $log->error($@) }
                or $err .= $@;
        }
    }
}

$log->debug("Finish all options! Goodbye!");

sub update_jobs {
    $log->info("Start update industry jobs");

    my ( $api, $account, $chars ) = _get_char_ids('industry_jobs');

    my $corp = ApiChecker::Core::Corp->new( $dbh, $api );

    foreach my $key ( @$chars ) {

        if ($key->{type} eq 'Corporation') {
            my $corp_id = $corp->get_corp_id_by_key( $key->{key_id} );
            $corp->set_industry_jobs( $key->{key_id}, $key->{vcode}, $corp_id );
        }
        else {
            $corp->set_industry_jobs( $key->{key_id}, $key->{vcode} );
        }
    }

    $log->info("Finish update_jobs");
}


sub _get_char_ids {
    my ( $table ) = @_;

    my $api = ApiChecker::Core::Api->new( $dbh );
    my $account = ApiChecker::Core::Account->new( $dbh, $api );

    my $where = '1 = 1 ';
    unless ( $force ) {
        $where = ' DATE_ADD( cwj.cached_until, INTERVAL 3 HOUR ) < NOW( ) OR cwj.cached_until IS NULL ';
    }
    if ( $for_id ) {
        $where = " aki.character_id = $for_id ";
    }
    if ( $only_key ) {
        $where = " aki.key_id = $only_key ";
    }

    my $queue = "SELECT aki.character_id, aki.type, aki.key_id, a.vcode
         FROM  api_key_info aki         
         LEFT  JOIN $table cwj ON aki.character_id = cwj.installer_id
         INNER JOIN api a ON a.key = aki.key_id       
         WHERE $where AND a.status = 1 AND a.deleted = 0
         GROUP BY aki.character_id;";

    my $chars = $dbh->selectall_arrayref($queue, { Slice => {} } );

    return ( $api, $account, $chars );
}

