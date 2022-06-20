package ApiChecker::Users;
use Mojo::Base 'Mojolicious::Controller';
use utf8;
use Modern::Perl;
use Data::Dumper;

use ApiChecker::Core::User;
use List::MoreUtils qw/ uniq /;
# This action will render a template
sub index {
	my $self = shift;

    my @errors = $self->session('errors');

    my $user = ApiChecker::Core::User->new( $self->stash('db') );

    if ( $self->req->method eq 'POST' ) {
        @errors = ();

        if ( $self->param('user_id') ) {
            my @roles = split ',', $self->param('roles');
            if ( scalar @roles > 0 ) {
                $user->remove_roles( $self->param('user_id') );
                @roles = uniq @roles;
                foreach my $role ( @roles ) {
                    $role =~ s/\s+//g;
                    next unless $role;
                    $user->add_role( $role, $self->param('user_id') );
                    push @errors, { text => "Роль $role успешно добавлена", type => 'success' };
                }
            }
            else {
                $user->remove_roles( $self->param('user_id') );
                push @errors, { text => 'Роли успешно удалены', type => 'success' };
            }
            $self->session( errors => \@errors );
            $self->redirect_to('/users' );
        }
        elsif ( $self->param('login') && $self->param('password') ) {

                if ( $user->get( $self->param('login') ) ) {
                    push @errors, { text => 'Такой уже есть.', type => 'danger' };
                    $self->session( errors => \@errors );
                    $self->redirect_to('/users' );
                    return;
                }
                unless ( $user->add( $self->param('login'), $self->param('password') ) ) {
                    push @errors, { text => 'Не удалось создать пользователя', type => 'danger' };
                }
                else {
                    push @errors, { text => 'Пользователь успешно добавлен', type => 'success' };
                }
        }
        else {
            push @errors, { text => 'Логин и пароль обязательно указать', type => 'danger' };
        }
        $self->session( errors => \@errors );
        $self->redirect_to('/users' );
    }

    my $users = $user->list();
    my $corps = $user->get_all_corps();

    foreach my $u ( @$users ) {
        $u->{corps} = $user->get_user_corps($u->{id});
    }

    $self->render(header => 'Управление пользователями', errors => @errors, users => $users, corps => $corps );
}

sub delete {
    my $self = shift;

    my $user = ApiChecker::Core::User->new( $self->stash('db') );

    my $status;
    if ( $self->param('id') && $self->param('id') =~ /\d+/ ) {
        $status = $user->remove( $self->param('id') );
    }
    $self->session( errors => [{text => 'Пользователь успешно удален', type => 'success'}] );
    $self->render( text => 'success' );
}

sub corps {
    my $self = shift;

    my $user_id = $self->param('id');
    my $corps   = $self->param('corps');

    my @corps = split ',', $corps;

    my $user = ApiChecker::Core::User->new( $self->stash('db') );
    $user->set_user_corps($user_id, \@corps);


    $self->render( text => 'success' );
}


1;
