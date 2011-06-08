package Router::PathInfo::Controller;
use strict;
use warnings;

use namespace::autoclean;
use Carp;
use Digest::MD5 qw(md5_hex);
use Data::Dumper;
use Module::Load;
#use re 'eval';

#use re 'debug';
#use diagnostics;


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
    my $supported_methods = shift;
    $supported_methods ||= [keys %$http_methods];
    my @http_methods = ref $supported_methods ? @$supported_methods : $supported_methods;
    
    my @ret = (0) x 6;
    for (@http_methods) {
        croak "unknown http method $_" unless exists $http_methods->{$_};
        $ret[$http_methods->{$_}] = '[10]';
    };
    
#    my $ee = join('', @ret);
#    $ee =~ s!
#        (0+) | ((\[10\])+)
#    !
#        if ($1) {
#            my $i = length $1;
#            $i > 1 ? "0{$i}" : '0';
#        } elsif ($2) {
#            my $i = length($2)/4;
#            $i > 1 ? "[10]{$i}" : '[10]';
#        }
#    !gex;
    return '#'.join('', @ret);
    
#    # optimize
#    my @ret_optimize = ();
#    my $i = 0; my $tmp = ''; my $in = 0;
#    for (@ret) {
#        if ($_ ne $tmp) {
#            if ($in) {
#                $in = 0;
#                push @ret_optimize,"{$i}" if $i > 1;
#                $i = 0;
#            } else {
#                $tmp = $_;
#                $in = 1;
#                $i = 1;
#                push @ret_optimize,$_;
#            }
#        } else {
#            $i++;
#        };
#    }
#    if ($in) {
#        
#    }
}


my $r = {
    postfix => '(?=/)',
    prefix  => '/'
};

my $rule = {
    ':enum'     => {
       re => sub {sprintf '%s(%s)', $r->{prefix}, $_[0],       $r->{postfix}},
       weight => 5  
    },
    'eq'        => {
       re => sub {sprintf '%s%s',   $r->{prefix}, $_[0],       $r->{postfix}},
       weight => 4
    },
    ':int'      => {
       re =>sub {sprintf '%s(%s)',  $r->{prefix}, '\d+',       $r->{postfix}},
       weight => 3    
    },
    ':num'      => {
       re => sub {sprintf '%s(%s)', $r->{prefix}, '\d+\.\d*',  $r->{postfix}},
       weight => 2   
    },
    ':any'      => {
       re => sub {sprintf '%s(%s)', $r->{prefix}, '[^/]+',     $r->{postfix}},
       weight => 7   
    },
    ':empty'    => {
       re => sub {'/(?=/)'},
       weight => 1 
    },
    ':endslash' => {
       re => sub {'/(?=#)'},
       weight => 0
    },
    ':re'       => {
       re => sub {sprintf '%s(%s)', $r->{prefix}, $_[0],     $r->{postfix}},
       weight => 6 
    }
};

sub new {
    my $class = shift;
    my $param = {@_};
    
    my $self = bless {
        rule => {},
        re => undef,
        start_index => 10000,
        connect_action => {},
        ind => 0
    }, $class;
    
    $self->load_rule_from_ini($param->{rules_file}) if $param->{rules_file};
    
    return $self;
}

sub _rules_md5 {md5_hex(Dumper(shift->{rule}))}

sub _make_index {
    my $self = shift;
    my $rest_index = shift;    
    my $i = $self->{start_index}++;
    #return ("(?{\$ret->[0]=$i})".$rest_index, $i);
    return ("#".$i.$rest_index, $i);
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
    my @re_weight = ();
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
                    push @re_weight, $rule->{':empty'}->{weight};
                } elsif ($2) {
                    push @re, $rule->{':endslash'}->{re}->();
                    push @re_weight, $rule->{':endslash'}->{weight};
                } elsif ($3) {
                    push @segment, $i;
                    push @re, $rule->{':num'}->{re}->();
                    push @re_weight, $rule->{':num'}->{weight};
                } elsif ($4) {
                    push @segment, $i;
                    push @re, $rule->{':int'}->{re}->();
                    push @re_weight, $rule->{':int'}->{weight};
                } elsif ($5) {
                    push @segment, $i;
                    push @re, $rule->{':enum'}->{re}->($5);
                    push @re_weight, $rule->{':enum'}->{weight};
                } elsif ($6) {
                    push @segment, $i;
                    push @re, $rule->{':re'}->{re}->($6);
                    push @re_weight, $rule->{':re'}->{weight};
                } elsif ($7) {
                    push @segment, $i;
                    push @re, $rule->{':any'}->{re}->();
                    push @re_weight, $rule->{':any'}->{weight};
                } elsif ($8) {
                    push @re, $rule->{'eq'}->{re}->($8);
                    push @re_weight, $rule->{'eq'}->{weight};
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
        my $rule_weight = shift @re_weight;
        unless (exists $cur_index->{$re.$r->{postfix}.'#'.$rule_weight}) {
            if ($ost) {
                $re .= $r->{postfix}.'#'.$rule_weight;
                $cur_index->{$re} = {};
                $cur_index = $cur_index->{$re}; 
            } else {
                my ($i, $si) = $self->_make_index($rest_index);
                my $in = $re.$i.'$#'.$rule_weight;
                $cur_index->{$in} = '';
                $self->{connect_action}->{$si} = {action => $args{action}, segment => [@segment]};
            }
        } else {
            if ($ost) {
                $re .= $r->{postfix}.'#'.$rule_weight;
                $cur_index = $cur_index->{$re}; 
            } else {
                my ($i, $si) = $self->_make_index($rest_index);
                my $in = $re.$i.'$#'.$rule_weight;
                $cur_index->{$in} = '';
                $self->{connect_action}->{$si} = {action => $args{action}, segment => [@segment]};
            }
        }
        
    }    
    
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

sub __dumper_cat {
    my $hash = shift;
    return [
       map {
        (my $new_key = $_) =~ s/#[0-7]$//;
        $hash->{$new_key} = delete $hash->{$_};
        $new_key;
       } sort {
        my $info = [{token => $a}, {token => $b}];
        for (0..1) {
            my @sp = split '#', $info->[$_]->{token};
            my $sp = @sp; 
            if ($sp == 1) {
                $info->[$_]->{weight} = $sp[1];
                $info->[$_]->{rest} = '1' x 25;
            } elsif ($sp == 3) {
                $info->[$_]->{weight} = $sp[2];
                $info->[$_]->{rest} = $sp[1];
            }
        }
        $info->[0]->{weight} <=> $info->[1]->{weight} || length $info->[0]->{rest} <=> length $info->[1]->{rest}

       } keys %{$hash}
    ]
}

## wrap string in single quotes (escaping if needed)
#sub _quote {my $val = shift;$val =~ s/([\\\'])/\\$1/g;return  "'" . $val .  "'";}

sub build_search_index {
    my $self = shift;
    return unless keys %{$self->{rule}};
    
    my $d = Data::Dumper->new([$self->{rule}]);
    $d->Indent(0)->Terse(1)->Pair('')->Sortkeys(\&__dumper_cat);
    my $index_re = $d->Dump();
    
    #->Varname('VAR')
    #$index_re =~ s/^\$VAR1 = //;
    #$index_re =~ s/;$//;
    $index_re =~ s#\{(?!\$ret\->\[0\]=\d{5})#(#g;
    $index_re =~ s#(?<!\$ret\->\[0\]=\d{5})\}#)#g;
    $index_re =~ s/'//g;
    $index_re =~ s/,/|/g;
    # бляха от дампера, возможно это нужно решать по другому
    $index_re =~ s/\\\\/\\/g;

    $self->{re} = $index_re;
    #$self->{re} = qr{^$index_re$}s;
    
    return 1;
}

#sub _build_search_index {
#    my $self = shift;
#    my $rule = shift || $self->{rule};
#    return unless keys %$rule;
#    my @ret = ();
#    my $keys_rule = __dumper_cat($rule);
#    for my $k (@$keys_rule) {
#        if (ref $rule->{$k}) {
#           $k.=$self->_build_search_index($rule->{$k}); 
#           push @ret,$k;
#        } else {
#           push @ret, $k 
#        }
#    }
#    
#    return '('.join('|',@ret).')';
#}
#
#sub build_search_index {
#    my $self = shift;
#    my $re = $self->_build_search_index;
#    $self->{re} = qr/$re/s;
#    return 1;
#}

sub __make_index_from_match {
    return unless @_; 
    my @ind = grep {defined $_ and $_ eq int($_)} @_[-4..-1];
    return ':#'.join('', @ind);
}


sub match {
    my $self = shift;
    my $env = shift;
    
    my @rest = (0) x 6;
    $rest[$http_methods->{$env->{REQUEST_METHOD}}] = 1;
    
    my $path = $env->{PATH_INFO}.'#'.join('', @rest); 
    
    my $ret = [];
    #$path =~ $self->{re};
    
    #my $codeToEval = '$path =~ m!^'.$self->{re}.'$!s;';
    #eval $codeToEval;
    #1;
    
    if ($ret->[0]) {
        my $container = $self->{connect_action}->{$ret->[0]};
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