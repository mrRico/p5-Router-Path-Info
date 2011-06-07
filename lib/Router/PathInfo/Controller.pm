package Router::PathInfo::Controller;
use strict;
use warnings;

use namespace::autoclean;
use Carp;
use Digest::MD5 qw(md5_hex);
use Data::Dumper;
use Module::Load;

#x sort {length $a <=> length $b} ($ee1,$ee2,$ee3, $ee4)
#0  0000
#1  '0(1|0)00'
#2  '(1|0)000'
#3  '(1|0)(1|0)(1|0)(1|0)'

#my $default_rule_methods = '1'.(0 x 7);
#my $all_rule_methods = '1' x 8;

my $http_methods = {
    GET     => 0,
    POST    => 1,
    PUT     => 2,
    OPTIONS => 3,
    DELETE  => 4,
    HEAD    => 5
};

# rest
sub __make_rule_http_access {
    my $http_methods = shift;
    $http_methods ||= [keys %$http_methods];
    my @http_methods = ref $http_methods ? @$http_methods : $http_methods;
    
    my @ret = (0) x 6;
    for (@http_methods) {
        croak "unknown http method $_" unless exists $http_methods->{$_};
        $ret[$http_methods->{$_}] = '(1|0)';
    }; 
    return join('', @ret);
}


my $r = {
    postfix => '(?=/)',
    prefix  => '/'
};

my $rule = {
    ':enum'     => {
       re => sub {sprintf '%s(%s)', $r->{prefix}, $_[0],       $r->{postfix}}   
    },
    'eq'        => {
       re => sub {sprintf '%s%s', $r->{prefix}, $_[0],       $r->{postfix}}
    },
    ':int'      => {
       re =>sub {sprintf '%s(%s)', $r->{prefix}, '\d+',       $r->{postfix}}    
    },
    ':num'      => {
       re => sub {sprintf '%s(%s)', $r->{prefix}, '\d+\.\d*',  $r->{postfix}}   
    },
    ':any'      => {
       re => sub {sprintf '%s(%s)', $r->{prefix}, '[^/]+',     $r->{postfix}}   
    },
    ':empty'    => {
       re => sub {'/(?=/)'} 
    },
    ':endslash' => {
       re => sub {'/(?=:#)'}
    },
    ':re'       => {
       re => sub {sprintf '%s(%s)', $r->{prefix}, $_[0],     $r->{postfix}} 
    }
};

sub new {
    my $class = shift;
    my $param = {@_};
    
    my $self = bless {
        rule => {},
        re => undef,
        start_index => 0,
        connect_action => {}
    }, $class;
    
    $self->load_rule_from_ini($param->{rules_file}) if $param->{rules_file};
    
    return $self;
}

sub _rules_md5 {md5_hex(Dumper(shift->{rule}))}

sub _make_index {
    my $self = shift;    
    my $i = sprintf '%04d', $self->{start_index}++;
    my @i = split '', $i;
    @i = map {'\d*('.$_.')\d*'} @i; 
    return (':#'.join('.', @i), ':#'.$i); 
}

sub add_rule {
    my ($self, %args) = @_;
    
    for ( ('connect', 'action') ) {
         unless ($args{$_}) {
             carp "missing '$_'";
             return;
         };
    }
    
    # buld rest index
    my $rest_index = __make_rule_http_access($args{methods});
    
    my @re = ();
    my @segment = ();
    my $i = 1;
    (my $connect = $args{connect}) =~ s!  
                (/)(?=/)                    | # double slash
                (/$)                        | # end slash 
                /(:num)(?= $|/)             | # decimal
                /(:int)(?= $|/)             | # int
                /:enum\(([^/]+)\)(?= $|/)   | # enum
                /:re\(([^/]+)\)(?= $|/)     | # re
                /(:any)(?= $|/)             | # any
                /([^/]+)(?= $|/)              # eq
            !
                if ($1) {
                    push @re, $rule->{':empty'}->{re}->();
                } elsif ($2) {
                    push @re, $rule->{':endslash'}->{re}->();
                } elsif ($3) {
                    push @segment, $i;
                    push @re, $rule->{':num'}->{re}->();
                } elsif ($4) {
                    push @segment, $i;
                    push @re, $rule->{':int'}->{re}->();
                } elsif ($5) {
                    push @segment, $i;
                    push @re, $rule->{':enum'}->{re}->($5);
                } elsif ($6) {
                    push @segment, $i;
                    push @re, $rule->{':re'}->{re}->($6);
                } elsif ($7) {
                    push @segment, $i;
                    push @re, $rule->{':any'}->{re}->();
                } elsif ($8) {
                    push @re, $rule->{'eq'}->{re}->($8);
                } else {
                    # default as word
                    croak "cant't resolve connect ".$args{connect}
                }
                $i++;
            !gex;    
    
    
    my $cur_index = $self->{rule};
    while (@re) {
        my $re = shift @re;
        my $ost = @re;
        unless (exists $cur_index->{$re}) {
            if ($ost) {
                $re .= $r->{postfix};
                $cur_index->{$re} = {};
                $cur_index = $cur_index->{$re}; 
            } else {
                my ($i, $si) = $self->_make_index();
                my $in = $re.$i.'$';
                carp "$connect overload old value" if exists $cur_index->{$in};
                $cur_index->{$in} = '';
                $self->{connect_action}->{$si} = {action => $args{action}, segment => [@segment]};
            }
        } else {
            if ($ost) {
                $re .= $r->{postfix};
                $cur_index = $cur_index->{$re}; 
            } else {
                my ($i, $si) = $self->_make_index();
                my $in = $re.$i.'$';
                carp "$connect overload old value" if exists $cur_index->{$in};
                $cur_index->{$in} = '';
                $self->{connect_action}->{$si} = {action => $args{action}, segment => [@segment]};
            }
        }
        
    }    
    
    
#    while (@re) {
#        my $re = shift @re;
#        my $ost = @re;
#        unless (exists $cur_index->{$re}) {
#            if ($ost) {
#                $re .= $r->{postfix};
#                $cur_index->{$re} = {};
#                $cur_index = $cur_index->{$re}; 
#            } else {
#                my ($i, $si) = $self->_make_index();
#                my $in = $re.$i.'$';
#                carp "$connect overload old value" if exists $cur_index->{$in};
#                $cur_index->{$in} = '';
#                $self->{connect_action}->{$si} = {action => $args{action}, segment => [@segment]};
#            }
#        } else {
#            if ($ost) {
#                $re .= $r->{postfix};
#                $cur_index = $cur_index->{$re}; 
#            } else {
#                my ($i, $si) = $self->_make_index();
#                my $in = $re.$i.'$';
#                carp "$connect overload old value" if exists $cur_index->{$in};
#                $cur_index->{$in} = '';
#                $self->{connect_action}->{$si} = {action => $args{action}, segment => [@segment]};
#            }
#        }
#        
#    }    
    
    return 1;
}


sub load_rule_from_ini {
    my $self = shift;
    my $file = shift;
    return unless $file; 
    unless (-f $file and -r _) {
        carp "can't read file '$file'";
        return;
    };
    
    load 'Config::Tiny';
    my $rewrite = Config::Tiny->read($file) || {};
    
    foreach my $r (keys %$rewrite) {
        next unless UNIVERSAL::isa($rewrite->{$r}, 'HASH');
        $self->add_rule(
            'connect'   => $_,
            %{$rewrite->{$r}}
        );
    }
       
    return 1;
}

sub build_search_index {
    my $self = shift;
    return unless keys %{$self->{rule}};
    
    my $d = Data::Dumper->new([$self->{rule}]);
    $d->Indent(0)->Varname('VAR')->Pair('');
    my $index_re = $d->Dump();
    
    $index_re =~ s/^\$VAR1 = //;
    $index_re =~ s/;$//;
    $index_re =~ s/\{/(/g;
    $index_re =~ s/\}/)/g;
    $index_re =~ s/'//g;
    $index_re =~ s/,/|/g;
    # бляха от дампера, возможно это нужно решать по другому
    $index_re =~ s/\\\\/\\/g;

    $self->{re} = qr{^$index_re$};
    
    return 1;
}


sub __make_index_from_match {
    return unless @_; 
    my @ind = grep {defined $_ and $_ eq int($_)} @_[-4..-1];
    return ':#'.join('', @ind);
}


sub match {
    my $self = shift;
    my $env = shift;
    
    my $path = $env->{PATH_INFO}.':#'.join('.', ('0123456789') x 4 ); 
    
    my @res = $path =~ $self->{re};
    my $match = __make_index_from_match(@res);
    
    if ($match) {
        my $container = $self->{connect_action}->{$match};
        if ($container) {
            my @segment = map {$env->{'psgix.RouterPathInfo'}->{segment}->[$_]} @{$container->{segment}};
            return {
                type => 'controller',
                action => $container->{action},
                segment => [@segment] 
            }
        }
    }
    
    return;
}




1;
__END__
