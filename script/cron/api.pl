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
use lib '/www/games-eveonline-evecentral/lib';
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

        api_keys
        
        get_mails
        get_names
        contacts
        transactions
        journal
        character_sheet
        assets
        account_status
        skill_training
        contracts
        corp_assets
    /,
    "id=i"  => \$for_id,
    "key=i" => \$only_key,
) or die;
# get_characters_names

# if ( my $pid = Proc::PID::File->running({dir=>'/www/api_checker/log/', verify=>1}) ) {
#     print  'Already running, pid='.$pid;
#     exit 1;
# }

my %action_for = (
    'api_keys'              => \&check_api_keys,
    'get_names'             => \&get_characters_names,
    'get_mails'             => \&get_mails,
    'contacts'              => \&contacts,
    'transactions'          => \&transactions,
    'journal'               => \&journal,
    'character_sheet'       => \&character_sheet,
    'assets'                => \&assets,
    'account_status'        => \&account_status,
    'skill_training'        => \&skill_training,
    'contracts'             => \&contracts,
    # 'get_cranb_contracts'   => \&get_cranb_contracts,
    'corp_assets'           => \&corp_assets,
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

my $log = Log::Log4perl->get_logger('api_cron');

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

sub get_cranb_contracts {
    $log->info("Start get_cranb_contravts");

    my $api = ApiChecker::Core::Api->new( $dbh );
    my $account = ApiChecker::Core::Account->new( $dbh, $api );

    my $chars = YAML::Tiny->read( '/www/api_checker/config/cranb_chars.yaml' )->[0];
    
    foreach my $char_id ( @$chars) {
        $log->info("Get contracts for " .  $char_id);
        eval {
            $account->set_contracts(  $char_id );
        };

        if ( @! ) {
            $log->error("Falied for $char_id: $_\n" . Dumper(\@_) );
        }

        $log->info("end contracts for " .  $char_id);
    }

    $log->info("Finish cranb contracts");
}

sub check_api_keys {
    $log->info("Start check_api_keys");

    if ( $for_id ) {
       $log->info("Skip check_api_keys cause --id is not null");
       return;
    }

    my $api = ApiChecker::Core::Api->new( $dbh );
    my $apis = $api->list( 1 );

    my $account = ApiChecker::Core::Account->new( $dbh, $api );

    foreach my $key ( @$apis ) {
        next if $key->{type} eq 'Corporation';
        next if defined $only_key && $only_key !=  $key->{key};
        my $status = $account->set_api_key_info( $key->{key}, $key->{vcode} );
        if ( $status ) {
            $log->info( 'key = ' . $key->{key} . ' is valid' );
        }
        else {
            $log->info( 'key = ' . $key->{key} . ' is invalid' );
            $api->update_status( 0, $key->{key} );
        }
    }

    $log->info("Finish check_api_keys");
}

sub skill_training {
    $log->info("Start skill in training");

    my ( $api, $account, $chars ) = _get_char_ids('character_skill_training');

    foreach my $char_id ( @$chars ) {
        $log->info("Get skill training for " .  $char_id);
        eval {
            $account->set_character_skill_training(  $char_id );
        };

        if ( @! ) {
            $log->error("Falied for $char_id: $_\n" . Dumper(\@_) );
        }

        $log->info("end skill_training for " .  $char_id);
    }


    $log->info("Finish skill in training");
}

sub contracts {
    $log->info("Start contracts");

    my ( $api, $account, $chars ) = _get_char_ids('character_contracts');

    foreach my $char_id ( @$chars ) {
        $log->info("Get contracts for " .  $char_id);
        eval {
            $account->set_contracts(  $char_id );
        };

        if ( @! ) {
            $log->error("Falied for $char_id: $_\n" . Dumper(\@_) );
        }

        $log->info("end contracts for " .  $char_id);
    }


    $log->info("Finish contracts");
}

sub get_characters_names {
    $log->info("Start get_characters_names");

    my $api = ApiChecker::Core::Api->new( $dbh );
    my $eve = ApiChecker::Core::Eve->new( $dbh, $api );
    
    eval { $eve->set_character_ids(); };
   
    if ( @! ) {
        $log->error("Failed: $_ \n" . Dumper(\@_) );
    }

    $log->info("Finish get_characters_names");
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

    my $queue = "SELECT aki.character_id
         FROM  api_key_info aki         
         LEFT  JOIN $table cwj ON aki.character_id = cwj.character_id
         INNER JOIN api a ON a.key = aki.key_id       
         WHERE $where AND a.status = 1 AND a.deleted = 0
         GROUP BY aki.character_id;";

    my $chars = $dbh->selectcol_arrayref($queue, undef );

    return ( $api, $account, $chars );
}

sub _get_corp_char_ids {
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
         LEFT  JOIN $table cwj ON aki.character_id = cwj.character_id
         INNER JOIN api a ON a.key = aki.key_id       
         WHERE $where AND a.status = 1 AND a.deleted = 0 AND aki.type = 'Corporation'
         GROUP BY aki.character_id;";

    my $chars = $dbh->selectall_arrayref($queue, { Slice => {}} );

    return ( $api, $account, $chars );
}

sub get_mails {
    $log->info("Start get_mails");

    my ( $api, $account, $chars ) = _get_char_ids('character_mails');

    foreach my $char_id ( @$chars ) {
        #my $mess_ids = $account->get_message_ids(  $char_id );
        #$log->info("Already have " . scalar @$mess_ids . " mails");
        $log->info("Set mails for " .  $char_id);

        eval { $account->set_mails( $char_id ); };
        if ( @! ) {
            $log->error("Failed for $char_id: $_ \n" . Dumper(\@_) );
        }
        eval { $account->set_mail_lists(  $char_id ); };
        $log->info("END get mails for " .  $char_id);
    }

    get_characters_names();

    $log->info("Finish get_mails");
}


sub contacts {
    $log->info("Start contacts");

    my ( $api, $account, $chars ) = _get_char_ids('character_contacts');

    foreach my $char_id ( @$chars ) {
        $log->info("Get contacts for " .  $char_id);
        eval {
            $account->set_character_contacts(  $char_id );
        };

        if ( @! ) {
            $log->error("Falied for $char_id: $_\n" . Dumper(\@_) );
        }

        $log->info("end contacts for " .  $char_id);
    }


    $log->info("Finish contacts");
}

sub transactions {
    $log->info("Start transactions");

    my ( $api, $account, $chars ) = _get_char_ids('character_wallet_transactions');

    foreach my $char_id ( @$chars ) {
        $log->info("Get transactions for " .  $char_id);
        eval {
            $account->set_wallet_transactions(  $char_id );
        };
        if ( @! ) {
            $log->error("Falied for $char_id: $_\n" . Dumper(\@_) );
        }
        $log->info("end transactions for " .  $char_id);
    }

    $log->info("Finish transactions");
}

sub journal {
    $log->info("Start journal");

    my ( $api, $account, $chars ) = _get_char_ids('character_wallet_journal');

    foreach my $char_id ( @$chars ) {
        $log->info("Get journal for " .  $char_id);
        # eval {
            $account->set_wallet_journal(  $char_id );
        # };
        if ( @! ) {
            $log->error("Falied for $char_id: $_\n" . Dumper(\@_) );
        }
        $log->info("end journal for " .  $char_id);
    }

    $log->info("Finish journal");
}

sub character_sheet {
    $log->info("Start character_sheet");

    my ( $api, $account, $chars ) = _get_char_ids('character_sheet');
    my $eve = ApiChecker::Core::Eve->new( $dbh, $api );

    foreach my $char_id ( @$chars ) {
        $log->info("Get character sheet for " .  $char_id);
        eval {
            $account->set_character_sheet(  $char_id );
        };

        if ( @! ) {
            $log->error("Falied for $char_id: $_\n" . Dumper(\@_) );
        }
        eval {
            $eve->set_character_info( [ $char_id ] );
        };

        $log->info("end character sheet for " .  $char_id);
    }

    $log->info("Finish character_sheet");
}

sub corp_assets {
    $log->info("Start corp_assets");

    my ( $api, $account, $chars ) = _get_corp_char_ids('character_assets');
    my $corp = ApiChecker::Core::Corp->new( $dbh, $api );

;
    foreach my $char ( @$chars ) {
        $log->info("Get assets for corp-char " .  $char->{character_id});
        my $corp_id = $corp->get_corp_id_by_key( $char->{key_id} );
        eval {
            $account->set_corp_assets( $char->{key_id}, $char->{vcode}, $corp_id );
        };

        if ( @! ) {
            $log->error("Failed: $_\n" . Dumper(\@_) );
        }

        $log->info("end assets for " .  $char->{character_id} );
    }

    $log->info("Finish corp_assets");
}


sub assets {
    $log->info("Start assets");

    my ( $api, $account, $chars ) = _get_char_ids('character_assets');

    foreach my $char_id ( @$chars ) {
        $log->info("Get assets for " .  $char_id);
        eval {
            $account->set_character_assets( $char_id );
        };

        if ( @! ) {
            $log->error("Failed for $char_id: $_\n" . Dumper(\@_) );
        }

        $log->info("end assets for " .  $char_id);
    }

    $log->info("Finish assets");
}

sub account_status {
    $log->info("Start account_status");

    if ( $for_id ) {
       $log->info("Skip account_status cause --id is not null");
       return;
    }

    my $api = ApiChecker::Core::Api->new( $dbh );
    my $account = ApiChecker::Core::Account->new( $dbh, $api );

    my $where = ' 1 = 1 ';
    unless ( $force ) {
        $where = ' DATE_ADD( cwj.cached_until, INTERVAL 3 HOUR ) < NOW( ) OR cwj.cached_until IS NULL';
    }

    if ( $only_key ) {
        $where = " cwj.key_id = $only_key ";
    }

    my $chars = $dbh->selectall_arrayref("SELECT cwj.key_id, vcode
            FROM  `account_status` cwj
            INNER JOIN api a ON a.key = cwj.key_id
            WHERE $where AND a.status = 1 AND a.mask = 268435455 AND a.deleted = 0
            GROUP BY cwj.key_id", { Slice => {} });

    foreach my $char ( @$chars ) {
        $log->info("Get account_status for " .  $char->{key_id});
        eval {
            $account->set_account_status(  $char->{key_id}, $char->{vcode} );
        };
        
        if ( @! ) {
            $log->error("Falied for " . $char->{key_id} . ": $_\n" . Dumper(\@_) );
        }
        $log->info("end account_status for " .  $char->{key_id});
    }

    $log->info("Finish account_status");
}
