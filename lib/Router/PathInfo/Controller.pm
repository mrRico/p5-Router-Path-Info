package Router::PathInfo::Controller;
use strict;
use warnings;

use namespace::autoclean;
use Carp;
use Data::Dumper;
use Digest::MD5 qw(md5_hex);

my $http_methods = {
    GET     => 1,
    POST    => 1,
    PUT     => 1,
    OPTIONS => 1,
    DELETE  => 1,
    HEAD    => 1
};

sub new {
    my $class = shift;
    my $param = {@_};
    
    my $self = bless {
        rule => {},
        re_compile => {},
    }, $class;
    
    return $self;
}

sub _rules_md5 {md5_hex(Dumper(shift->{rule}))}

sub add_rule {
    my ($self, %args) = @_;
    
    for ( ('connect', 'action') ) {
         unless ($args{$_}) {
             carp "missing '$_'";
             return;
         };
    }
    
    my $methods = $http_methods->{$args{method}} ? $args{method} : 'GET';
    my $sub_after_match = $args{match_callback} if ref $args{match_callback} eq 'CODE';
    
    my @depth = split '/',$args{connect},-1;
    
    my @segment = (); my $i = 0;
    $self->{rule}->{$methods}->{$#depth} ||= {};
    my $res = $self->{rule}->{$methods}->{$#depth};
    (my $tmp = $args{connect}) =~ s!  
                (/)(?=/)                    | # double slash
                (/$)                        | # end slash
                /:enum\(([^/]+)\)(?= $|/)   | # enum
                /:re\(([^/]+)\)(?= $|/)     | # re
                /(:any)(?= $|/)             | # any
                /([^/]+)(?= $|/)              # eq
            !
                if ($1 or $2) {
                    if (ref $res eq 'ARRAY') {
                        $_->{exactly}->{''} ||= {} for @$res;
                        $res = [map {$_->{exactly}->{''}} @$res];
                    } else {
                        $res->{exactly}->{''} ||= {};
                        $res = $res->{exactly}->{''};
                    }
                } elsif ($3) {
                    if (ref $res eq 'ARRAY') {                        
                        my @val = split('|',$3);
                        my @tmp;
                        for my $val (@val) {
                            for (@$res) {
                                $_->{exactly}->{$val} ||= {};
                                push @tmp, $_->{exactly}->{$val}; 
                            };
                        }
                        $res = [@tmp];
                    } else {
                        my @val = split('|',$3);
                        my @tmp;
                        for (@val) {
                            $res->{exactly}->{$_} ||= {};
                            push @tmp, $res->{exactly}->{$_};
                        }
                        $res = [@tmp];
                    }
                    push @segment, $i;
                } elsif ($4) {
                    $self->{re_compile}->{$4} = qr{$4}s;
                    
                    if (ref $res eq 'ARRAY') {
                        $_->{regexp}->{$4} ||= {} for @$res;
                        $res = [map {$_->{regexp}->{$4}} @$res];
                    } else {
                        $res->{regexp}->{$4} ||= {};
                        $res = $res->{regexp}->{$4};
                    }
                    push @segment, $i;
                } elsif ($5) {
                    if (ref $res eq 'ARRAY') {
                        $_->{default}->{''} ||= {} for @$res;
                        $res = [map {$_->{default}->{''}} @$res];
                    } else {
                        $res->{default}->{''} ||= {};
                        $res = $res->{default}->{''};
                    }
                    push @segment, $i;
                } elsif ($6) {
                    if (ref $res eq 'ARRAY') {
                        $_->{exactly}->{$6} ||= {} for @$res;
                        $res = [map {$_->{exactly}->{$6}} @$res];
                    } else {
                        $res->{exactly}->{$6} ||= {};
                        $res = $res->{exactly}->{$6};
                    }
                } else {
                    # default as word
                    croak "cant't resolve connect '$args{connect}'"
                }
                $i++;
            !gex;
        
        my $has_segment = @segment;
        if (ref $res eq 'ARRAY') {
            $_->{match} = [$args{action}, $has_segment ? [@segment] : undef, $sub_after_match] for @$res;
        } else {
            $res->{match} = [$args{action}, $has_segment ? [@segment] : undef, $sub_after_match];
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
        $self->{rule}->{$env->{PATH_INFO}}->{$depth}, 
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


#sub match {
#    my $self = shift;
#    my $env = shift;
#    
#    my @rest = (0) x 6;
#    $rest[$http_methods->{$env->{REQUEST_METHOD}}] = 1;
#    
#    my $path = $env->{PATH_INFO}.'#'.join('', @rest).'#1'.('0123456789' x 4); 
#    
#    my $rea = 0;
#    
#    #$path =~ s!^$self->{re}$!
#    #    print "----- ",$&,"\n";
#    #!xe;
#    
#    #my @res = grep {defined $_} $path =~ $self->{re};
#    my @res = grep {defined $_} $path =~ $self->{re};
#    #do {my $ret = []; $path =~ m!^$self->{re}$!s; $rea = $ret->[0]; undef $ret;};
#    #my $codeToEval = '$path =~ m!^'.$self->{re}.'$!s;';
#    #eval $codeToEval;
#    #1;
#    my $match = __make_index_from_match(@res);
#    if ($match) {
#        my $container = $self->{connect_action}->{$match};
#        if ($container) {
#            my @segment = map {$env->{'psgix.RouterPathInfo'}->{segment}->[$_]} @{$container->{segment}};
#            return {
#                type => 'controller',
#                action => $container->{action},
#                segment => [@segment] 
#            }
#        }
#    }
#    return;
#}




1;
__END__