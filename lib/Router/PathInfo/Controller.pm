package Router::PathInfo::Controller;
use strict;
use warnings;

=head1 NAME

B<Router::PathInfo::Controller> provides a mapping PATH_INFO to controllers

=head1 SYNOPSIS
    
    # create instance
    my $r = Router::PathInfo::Controller->new();
    
    # describe connect
    $r->add_rule(connect => '/foo/:enum(bar|baz)/:any', action => ['some','bar']);
    
    # prepare arguments (this action to prepare $env hidden from you in the module Router::PathInfo)
    my $env = {PATH_INFO => '/foo/baz/bar', REQUEST_METHOD => 'GET'};
    my @segment = split '/', $env->{PATH_INFO}, -1; 
    shift @segment;
    $env->{'psgix.tmp.RouterPathInfo'} = {
        segments => [@segment],
        depth => scalar @segment 
    };
    
    # match
    my $res = $r->match($env);  
	#  $res =  HASH(0x93d74d8)
	#   'action' => ARRAY(0x99294e8)
	#      0  'some'
	#      1  'bar'
	#   'segment' => ARRAY(0x93d8038)
	#      0  'baz'
	#      1  'bar'
	#   'type' => 'controller'

    # or $res may by undef

=head1 DESCRIPTION

C<Router::PathInfo::Controller> is used for matching sets of trees. 
Therefore, search matching is faster and more efficient, 
than a simple enumeration of regular expressions to search for a suitable result.

In the descriptions of 'C<connect>' by adding rules, you can use these tokens:

    :any                                 - match with any segment
    :re(...some regular expression...)   - match with the specified regular expression
    :enum(...|...)                       - match with a segment from the set

For example
    
    '/foo/bar/:any'
    '/foo/:re(:re(^\d{4}\w{4}$))/:any'
    '/:enum(foo|bar|baz)/:re(:re(^\d{4}\w{4}$))/:any'
 
All descriptions of the segments have a certain weight. 
Thus, the description C<:enum> has the greatest weight, a description of C<:re> weighs even less. Weakest coincidence is C<:any>.

For all descriptions 'C<connect>' using these tokens in the match will be returned to a special key 'C<segment>' 
in which stores a list of all segments C<PATH_INFO> they are responsible.

An important point: description 'C<connect>' dominates over http method. Example:
    
    $r->add_rule(connect => '/foo/:any/baz', action => 'one', methods => ['GET','DELETE']);
    $r->add_rule(connect => '/foo/bar/:any', action => 'two');
    
    for '/foo/bar/baz' with GET -> 'two'

In C<action> you can pass any value: object, arrayref, hashref or a scalar.

=head1 METHODS

=cut

use namespace::autoclean;
use Carp;
use Data::Dumper;

my $http_methods = {
    GET     => 1,
    POST    => 1,
    PUT     => 1,
    OPTIONS => 1,
    DELETE  => 1,
    HEAD    => 1
};

=head2 new()

Simple constructor  

=cut
sub new {
    bless {
        rule => {},
        re_compile => {},
    }, shift;
}

=head2 add_rule(connect => $describe_connect, action => $action_token[, methods => $arrayref, match_callback => $code_ref])

Added your description to match.

=cut
sub add_rule {
    my ($self, %args) = @_;
    
    for ( ('connect', 'action') ) {
         unless ($args{$_}) {
             carp "missing '$_'";
             return;
         };
    }
    $args{methods} = $args{methods} ? [grep {$http_methods->{$_}} (ref $args{methods} eq 'ARRAY' ? @{$args{methods}} : $args{methods})] : [];
    my @methods =   $args{methods}->[0] ? @{$args{methods}} : keys %$http_methods;
    my $methods_weight = $#methods; 
    
    my $sub_after_match = $args{match_callback} if ref $args{match_callback} eq 'CODE';
    
    my @depth = split '/',$args{connect},-1;
    
    my @segment = (); my $i = 0;
    
    my $res = [];
    for (@methods) {
        $self->{rule}->{$_}->{$#depth} ||= {};
        push @$res, $self->{rule}->{$_}->{$#depth};
    }
    
    (my $tmp = $args{connect}) =~ s!  
                (/)(?=/)                    | # double slash
                (/$)                        | # end slash
                /:enum\(([^/]+)\)(?= $|/)   | # enum
                /:re\(([^/]+)\)(?= $|/)     | # re
                /(:any)(?= $|/)             | # any
                /([^/]+)(?= $|/)              # eq
            !
                if ($1 or $2) {                    
                    $_->{exactly}->{''} ||= {} for @$res;
                    $res = [map {$_->{exactly}->{''}} @$res];
                } elsif ($3) {
                    my @val = split('\|',$3);
                    my @tmp;
                    for my $val (@val) {
                        for (@$res) {
                            $_->{exactly}->{$val} ||= {};
                            push @tmp, $_->{exactly}->{$val}; 
                        };
                    }
                    $res = [@tmp];
                    push @segment, $i;
                } elsif ($4) {
                    $self->{re_compile}->{$4} = qr{$4}s;
                    $_->{regexp}->{$4} ||= {} for @$res;
                    $res = [map {$_->{regexp}->{$4}} @$res];
                    push @segment, $i;
                } elsif ($5) {
                    $_->{default}->{''} ||= {} for @$res;
                    $res = [map {$_->{default}->{''}} @$res];
                    push @segment, $i;
                } elsif ($6) {
                    $_->{exactly}->{$6} ||= {} for @$res;
                    $res = [map {$_->{exactly}->{$6}} @$res];
                } else {
                    # default as word
                    croak "cant't resolve connect '$args{connect}'"
                }
                $i++;
            !gex;
        
        my $has_segment = @segment;
        for (@$res) {
            if (not $_->{match} or $_->{match}->[3] >= $methods_weight) {
                # устанавливаем только если нет матча или матч был по полее общему описанию
                $_->{match} = [$args{action}, $has_segment ? [@segment] : undef, $sub_after_match, $methods_weight];
            }
        }

    return 1;
}

sub _match {
    my ($self, $reserch, $size_el, @el) = @_;
    my $ret;
    my $segment = shift @el;
    $size_el--;
    my $exactly = $reserch->{exactly}->{$segment};
    if (defined $exactly) {
        $ret = $size_el ? $self->_match($exactly, $size_el, @el) : $exactly->{match};
        return $ret if $ret; 
    };
    
    if ($reserch->{regexp}) {
        for (keys %{$reserch->{regexp}}) {
            if ($segment =~ $self->{re_compile}->{$_}) {
                $ret = $size_el ? $self->_match($reserch->{regexp}->{$_}, $size_el, @el) : $reserch->{regexp}->{$_}->{match};
                return $ret if $ret;
            };
        }
    };
    
    if ($reserch->{default}) {
        $ret = $size_el ? $self->_match($reserch->{default}->{''}, $size_el, @el) : $reserch->{default}->{''}->{match};
        return $ret if $ret;
    }
    
    return;
}

sub match {
	my $self = shift;
    my $env = shift;
    
    my $depth = $env->{'psgix.tmp.RouterPathInfo'}->{depth};
    
    my $match = $self->_match(
        $self->{rule}->{$env->{REQUEST_METHOD}}->{$depth}, 
        $depth, 
        @{$env->{'psgix.tmp.RouterPathInfo'}->{segments}}
    );
    
    if ($match) {
    	my $ret = {
            type => 'controller',
            action => $match->[0],
            segment => $match->[1] ? [map {$env->{'psgix.tmp.RouterPathInfo'}->{segments}->[$_]} @{$match->[1]}] : [] 
        };
    	if ($match->[2]) {
    		return $match->[2]->($ret,$env); 
    	} else {
    		return $ret;
    	}
    } else {
    	return;
    }
    
}

1;
__END__
