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
use ApiChecker::Core::Corp;
use ApiChecker::Core::Eve;
use ApiChecker::Core::ESI;
use ApiChecker::Core::Utils;

my $all_appenders  = YAML::Tiny->read( '/www/api_checker/config/log4perl.conf.yaml' )->[0]->{log4perl_appenders};
my $all_categories = YAML::Tiny->read( '/www/api_checker/config/log4perl.conf.yaml' )->[0]->{log4perl_categories};
my $config         = { %$all_appenders, %$all_categories };


Log::Log4perl->init($config);

my %opt = ();
# my $only_key;
GetOptions(
    \%opt,
    qw/
        help|h

        debug|d
        verbose|v+
        force|f

        update_structures
        check_starbases

    /,
    # "key=i" => \$only_key,
) or die;

my %action_for = (
    'check_starbases'   => \&check_starbases,
    'update_structures' => \&update_structures,
);


if ( $opt{help} ) {
    show_help();
    exit;
}

my $verbose = delete $opt{verbose} || 0;
my $debug   = delete $opt{debug}   || 0;
my $force   = delete $opt{force}   || 0;
# delete $opt{key};

my $log = Log::Log4perl->get_logger('corp_cron');

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

exit();

sub update_structures {
    $log->info("Start update_structures");
    
    my $corps_char_ids = $dbh->selectall_arrayref("SELECT aki.character_id, aki.corporation_id FROM api_key_info aki LEFT JOIN api a ON a.key = aki.key_id WHERE
        a.status = 1 AND a.deleted = 0 AND aki.refresh_token != '' GROUP BY aki.corporation_id", { Slice=>{}});

    foreach my $corp_char ( @$corps_char_ids ) {

        my $esi = ApiChecker::Core::ESI->new($dbh, $corp_char->{character_id});

        my $structures = $dbh->selectcol_arrayref("SELECT facility_id FROM industry_jobs WHERE corporation_id = ? GROUP BY facility_id", undef, $corp_char->{corporation_id});

        foreach ( @$structures ) {
            my $data = $esi->get_universe_structure_id($_);

            $esi->set_structure_id($_, $data) unless defined $data->{error};

            if (defined $data->{error}) {
                $log->error($data->{error});
            }
        }
    }
    $log->info("END update_structures"); 
}

sub check_starbases {
    $log->info("Start check_api_keys");

    my $api = ApiChecker::Core::Api->new( $dbh );
    my $apis = $api->corp_list();

    my $corp = ApiChecker::Core::Corp->new( $dbh, $api );

    # say Dumper $apis;
    foreach my $key ( @$apis ) {
        # next if defined $only_key && $only_key !=  $key->{key};

        $corp->set_starbase_list( $key->{key}, $key->{vcode} );

    }

    $log->info("Finish check_api_keys");

    return;
}

