package HTML::TagCloud::Extended;
use strict;
use base qw/HTML::TagCloud Class::Data::Inheritable/;
use Time::Local;

our $VERSION = '0.04';

__PACKAGE__->mk_classdata($_)
for qw/colors _epoch_level base_font_size font_size_range/;

__PACKAGE__->colors( HTML::TagCloud::Extended::TagColors->new(
    earliest => 'cccccc',
    earlier  => '9999cc',
    later    => '9999ff',
    latest   => '0000ff',
) );

__PACKAGE__->_epoch_level( [qw/earliest earlier later latest/] );
__PACKAGE__->base_font_size(24);
__PACKAGE__->font_size_range(12);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{epochs} = {};
    bless $self, $class;
}

sub add {
    my($self, $tag, $url, $count, $timestamp) = @_;
    $self->SUPER::add($tag, $url, $count);
    $self->{epochs}->{$tag} = $self->_timestamp2epoch($timestamp);
}

sub css {
    my $self = shift;
    my $css = '';
    foreach my $type ( keys %{ $self->colors } ) {
        my $color = $self->colors->{$type};
        my $class = "span.tagcloud_$type";
        $css .= "$class a {text-decoration: none; color: #${color};}\n";
    }
    return $css;
}

sub html {
    my($self, $limit_conf) = @_;
    my $tags = $self->html_tags($limit_conf);
	return "" unless $tags;
    return join "", @$tags;
}

sub html_tags {
    my($self, $limit_conf) = @_;
    $limit_conf ||= {};
    my $counts  = $self->{counts};
    my $urls    = $self->{urls};
    my $epochs  = $self->{epochs};

    unless(ref $limit_conf eq 'HASH') {
        $self->_croak(qq/Wrong setting for limiting./);
    }
    my @tags = $self->_splice_tags( %$limit_conf );

    if(scalar(@tags) == 0) {
        return "";
    } elsif (scalar(@tags) == 1) {
        my $tag = $tags[0];
        my $url = $urls->{$tag};
        my $size = $self->max_font_size;
        return qq|<span class="tagcloud_latest" style="font-size: ${size}px;">|
            .qq|<a href="$url">$tag</a></span>\n|;
    }

    @tags = sort{ $counts->{$b} <=> $counts->{$a} } @tags;
    my $min_count = $counts->{$tags[-1]};
    my $max_count = $counts->{$tags[0]};

    my $count_factor = HTML::TagCloud::Extended::Factor->new(
        min      => $min_count,
        max      => $max_count,
        range    => $self->max_font_size - $self->min_font_size,
    );

    @tags = sort { $epochs->{$b} <=> $epochs->{$a} } @tags;
    my $min_epoch = $epochs->{$tags[-1]};
    my $max_epoch = $epochs->{$tags[0]};

    my $epoch_factor = HTML::TagCloud::Extended::Factor->new(
        min      => $min_epoch,
        max      => $max_epoch,
        range    => 3,
    );

    my @html_tags = "";
    foreach my $tag ( sort @tags ) {
        my $count    = $counts->{$tag};
        my $url      = $urls->{$tag};
        my $epoch    = $epochs->{$tag};
        my $count_level = $count_factor->get_level($count);
        my $epoch_level = $epoch_factor->get_level($epoch);
        my $color_type  = $self->_epoch_level->[$epoch_level];
        my $font_size   = $self->min_font_size + $count_level;
        push @html_tags, qq|<span class="tagcloud_$color_type" style="font-size: ${font_size}px;">|
            .qq|<a href="$url">$tag</a></span>\n|;
    }
    return \@html_tags;
}

sub _splice_tags {
    my($self, $type, $count) = @_;
    $count += 0;
    my @tags = keys %{ $self->{counts} };
    unless($type) {
        return @tags;
    }
    $type = lc($type);
    unless($type =~ /^(?:counts|timestamp)/ ){
        $self->_croak(qq/Unknown limiting type "$type"./);
    }
    my $desc = $type =~ s/_desc$//i;
    $type = "epochs" if $type eq 'timestamp';
    @tags = sort { $self->{$type}->{$a} <=> $self->{$type}->{$b} } @tags;
    @tags = reverse(@tags) if $desc;

    return splice(@tags, 0, $count);
}

sub _timestamp2epoch {
    my($self, $timestamp) = @_;
    if($timestamp) {
        my($year, $month, $mday, $hour, $min, $sec);
        if($timestamp =~ /^(\d{4})[-\/]{0,1}(\d{2})[-\/]{0,1}(\d{2})\s{0,1}(\d{2}):{0,1}(\d{2}):{0,1}(\d{2})$/){
            $year  = $1;
            $month = $2;
            $mday  = $3;
            $hour  = $4;
            $min   = $5;
            $sec   = $6;
        } else {
            $self->_croak(qq/Wrong timestamp format "$timestamp"./);
        }
        my $epoch = timelocal($sec, $min, $hour, $mday, $month - 1, $year - 1900);
        return $epoch;
    } else {
        return time();
    }
}

sub max_font_size {
    my $self = shift;
    return $self->base_font_size + $self->font_size_range;
}

sub min_font_size {
    my $self = shift;
    my $num =  $self->base_font_size - $self->font_size_range;
    return $num > 0 ? $num : 0;
}

sub _croak {
    my($self, $msg) = @_;
    require Carp; Carp::croak($msg);
}

package HTML::TagCloud::Extended::Factor;

sub new {
    my $class = shift;
    my $self = bless {
        min     => 0,
        max     => 0,
        range   => 0,
        _factor => 0,
    }, $class;
    $self->_init(@_);
    return $self;
}

sub _init {
    my($self, %args) = @_;
    foreach my $key ( qw/min max range/ ) {
        if(exists $args{$key}){
            $self->{$key} = $args{$key};
        } else {
            $self->_croak(qq/"$key" not found./);
        }
    }
    my $range = $args{range};
    my $min = sqrt($args{min});
    my $max = sqrt($args{max});
    $min -= $range if($min == $max);
    $self->{_factor} = $range / ($max - $min);
}

sub get_level {
    my($self, $number) = @_;
    return int( ( sqrt($number + 0) - sqrt($self->{min}) ) * $self->{_factor} );
}

sub _croak {
    my($self, $msg) = @_;
    require Carp; Carp::croak($msg);
}

package HTML::TagCloud::Extended::TagColors;

sub new {
    my $class = shift;
    my $self = bless {
        earliest => '',
        earlier  => '',
        later    => '',
        latest   => '',
        @_,
    }, $class;
    return $self;
}

sub set {
    my($self, @args) = @_;
    while(my($type, $color) = splice(@args, 0, 2)) {
        $color =~ s/\#//;
        unless( $type =~ /(?:earliest|earlier|later|latest)/ ) {
            $self->_croak(qq/Wrong type. "$type". /
            .qq/Choose type from [earliest earlier later laterst]./);
        }
        unless( $color =~ /^[0-9a-fA-F]{6}$/ ) {
            $self->_croak(qq/Wrong number format "$color"./);
        }
        $self->{$type} = $color;
    }
}

sub _croak {
    my($self, $msg) = @_;
    require Carp; Carp::croak($msg);
}

1;
__END__

=head1 NAME

HTML::TagCloud::Extended - HTML::TagCloud extension

=head1 SYNOPSIS

    use HTML::TagCloud::Extended;

    my $cloud = HTML::TagCloud::Extended->new();

    $cloud->add($tag1, $url1, $count1, $timestamp1);
    $cloud->add($tag2, $url2, $count2, $timestamp2);
    $cloud->add($tag3, $url3, $count3, $timestamp3);

    my $html = $cloud->html_and_css( { timestamp_desc => 50 } );

=head1 DESCRIPTION

This is L<HTML::TagCloud> extension module.

This module allows you to register timestamp with tags.
And tags' color will be changed according to it's timestamp.

=head1 TIMESTAMP AND COLORS

When you call 'add()' method, set timestamp as last argument.

    $cloud->add('perl', 'http://www.perl.org', 20, '2005-07-15 00:00:00');

=head2 TIMESTAMP FORMAT

follow three types of format are allowed.

=over 4

=item 2005-07-15 00:00:00

=item 2005/07/15 00:00:00

=item 20050715000000

=back

=head2 COLORS

This module chooses color from follow four types according to tag's timestamp.

=over 4

=item earliest

=item earlier

=item later

=item latest

=back

You needn't to set colors becouse the default colors are set already.

But when you want to set colors by yourself, of course, you can.

    HTML::TagCloud::Extended->colors->set(
        earliest    => '#000000',
        earlier     => '#333333',
        later       => '#999999',
        latest      => '#cccccc',
    );

=head1 LIMITING

When you want to limit the amount of tags, 'html()', 'html_and_css()' and follow new method 'html_tags()'
need second argument as hash reference.

    $cloud->html_and_css( { counts => 20 } );

This is combination of sorting type and amount.

=head2 SORTING TYPE FOR LIMITING

=over 4

=item counts

=item counts_desc

=item timestamp

=item timestamp_desc

=back

=head1 OTHER NEW FEATURES

=over 4

=item html_tags

    my $html_tags = $cloud->html_tags({counts_desc => 20});

    print "<ul>\n";
    foreach my $html_tag ( @$html_tags ) {
        print "<li>$html_tag</li>\n";
    }
    print "</ul>\n";

=item base_font_size

    HTML::TagCloud::Extended->base_font_size(30);

default size is 24.

=item font_size_range

    HTML::TagCloud::Extended->font_size_range(10);

default range is 12.

=back

=head1 SEE ALSO

L<HTML::TagCloud>

=head1 AUTHOR

Lyo Kato E<lt>kato@lost-season.jpE<gt>

=head1 COPYRIGHT AND LICENSE

This library is free software. You can redistribute it and/or
modify it under the same terms as perl itself.

=cut

