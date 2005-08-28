package HTML::TagCloud::Extended;
use strict;
use warnings;
use base qw/Class::Data::Inheritable Class::Accessor::Fast/;
use Readonly;
use HTML::TagCloud::Extended::TagColors;
use HTML::TagCloud::Extended::TagList;
use HTML::TagCloud::Extended::Tag;
use HTML::TagCloud::Extended::Factor;

our $VERSION = '0.05';

Readonly my $DEFAULT_BASE_FONT_SIZE  => 24;
Readonly my $DEFAULT_FONT_SIZE_RANGE => 12;
Readonly my $DEFAULT_CSS_CLASS       => "tagcloud";

__PACKAGE__->mk_classdata('_epoch_level');
__PACKAGE__->_epoch_level([qw/earliest earlier later latest/]);

__PACKAGE__->mk_accessors(qw/
    colors
    tags
    base_font_size
    font_size_range
    css_class
/);

sub new {
    my $class = shift;
    my $self  = bless { }, $class;
    $self->_init(@_);
    return $self;
}

sub _init {
    my $self = shift;
    $self->_set_default_parameters();
    $self->_set_custom_parameters(@_);
    $self->colors( HTML::TagCloud::Extended::TagColors->new );
    $self->tags( HTML::TagCloud::Extended::TagList->new );
}

sub _set_default_parameters {
    my $self  = shift;
    $self->base_font_size( $DEFAULT_BASE_FONT_SIZE );
    $self->font_size_range( $DEFAULT_FONT_SIZE_RANGE );
    $self->css_class( $DEFAULT_CSS_CLASS );
}

sub _set_custom_parameters {
    my ($self, %args) = @_;
    if ( exists $args{base_font_size} ) {
        $self->base_font_size( $args{base_font_size} );
    }
    if ( exists $args{font_size_range} ) {
        $self->font_size_range( $args{font_size_range} );
    }
    if ( exists $args{css_class} ) {
        $self->css_class( $args{css_class} );
    }
}

sub add {
    my($self, $tag_name, $url, $count, $timestamp) = @_;
    my $tag = HTML::TagCloud::Extended::Tag->new(
        name      => $tag_name  || '',
        url       => $url       || '',
        count     => $count     || 0,
        timestamp => $timestamp,
    );
    $self->tags->add($tag);
}

sub max_font_size {
    my $self = shift;
    return $self->base_font_size + $self->font_size_range;
}

sub min_font_size {
    my $self = shift;
    my $num  = $self->base_font_size - $self->font_size_range;
    return $num > 0 ? $num : 0;
}

sub html_and_css {
    my ($self, $conf) = @_;
    my $html = qq|<style type="text/css">\n|.$self->css.qq|</style>\n|;
    $html .= $self->html($conf);
    return $html;
}

sub css {
    my $self = shift;
    my $css  = '';
    foreach my $type ( keys %{ $self->colors } ) {
        my $color = $self->colors->{$type};
        my $class = $self->css_class;
        foreach my $attr ( keys %$color ) {
            my $code = $color->{$attr};
            $css .= ".${class}.${type} a:${attr} {text-decoration: none; color: #${code};}\n";
        }
    }
    return $css;
}

sub html {
    my ($self, $conf) = @_;
    my $html_tags = $self->html_tags($conf);
    my $html = join "", @$html_tags;
    return $self->wrap_div($html);
}

sub wrap_span {
    my($self, $html) = @_;
    return "" unless $html;
    return sprintf qq|<span class="%s">\n%s</span>\n|, $self->css_class, $html;
}

sub wrap_div {
    my($self, $html) = @_;
    return "" unless $html;
    return sprintf qq|<div class="%s">\n%s</div>\n|, $self->css_class, $html;
}

sub html_tags {
    my($self, $conf) = @_;
    
    my $tags_amount = $self->tags->count;
    if ($tags_amount == 0) {
        return [];
    } elsif ($tags_amount == 1) {
        my $ite  = $self->tags->iterator;
        my $tag  = $ite->first;
        my $html = $self->create_html_tag($tag, 'latest', $self->max_font_size);
        return [$html];
    }

    $conf ||= {};
    my $order_by = $conf->{order_by} || 'name';
    $self->tags->sort($order_by);
    my $limit = $conf->{limit};
    my $tags  = $limit ? $self->tags->splice(0, $limit) : $self->tags;
    
    my $count_factor = HTML::TagCloud::Extended::Factor->new(
        min   => $tags->min_count,
        max   => $tags->max_count,
        range => $self->max_font_size - $self->min_font_size,
    );

    my $epoch_factor = HTML::TagCloud::Extended::Factor->new(
        min   => $tags->min_epoch,
        max   => $tags->max_epoch,
        range => 3,
    );

    my @html_tags = ();
    my $ite = $tags->iterator;
    while( my $tag = $ite->next ) {
        my $count_lv   = $count_factor->get_level($tag->count);
        my $epoch_lv   = $epoch_factor->get_level($tag->epoch);
        my $color_type = $self->_epoch_level->[$epoch_lv];
        my $font_size  = $self->min_font_size + $count_lv;
        my $html_tag   = $self->create_html_tag($tag, $color_type, $font_size);
        push @html_tags, $html_tag;
    }
    return \@html_tags;
}

sub create_html_tag {
    my($self, $tag, $type, $size) = @_;
    return sprintf qq|<span class="%s" style="font-size: %d"><a href="%s">%s</a></span>\n|,
        $type,
        $size,
        $tag->url,
        $tag->name;
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

    my $html = $cloud->html_and_css( {
        order_by => 'count_desc',
        limit    => 20,
    } );

    print $html;

=head1 DESCRIPTION

This is extension of L<HTML::TagCloud>.

This module allows you to register timestamp with tags.
And color of tags will be changed according to it's timestamp.

Now, this doesn't depend on L<HTML::TagCloud>.

=head1 TIMESTAMP

When you call 'add()' method, set timestamp as last argument.

    $cloud->add('perl','http://www.perl.org/', 20, '2005-07-15 00:00:00');

=head2 FORMAT

follow three types of format are allowed.

=over 4

=item 2005-07-15 00:00:00

=item 2005/07/15 00:00:00

=item 20050715000000

=back

=head1 COLORS

This module chooses color from follow four types according to tag's timestamp.

=over 4

=item earliest

=item earlier

=item later

=item latest

=back

You needn't to set colors because the default colors are set already.

But when you want to set colors by yourself, of course, you can.

    my $cloud = HTML::TagCloud::Extended->new;

    $cloud->colors->set(
        earliest => '#000000',
    );

    $cloud->colors->set(
        earlier => '#333333',
        later   => '#999999',
        latest  => '#cccccc',
   );

    # or, you can set color for each attribute
    $cloud->colors->set(
        earliest => {
            link    => '#000000',
            hover   => '#CCCCCC',
            visited => '#333333',
            active  => '#666666',
        },
    );

=head1 LIMITTING

When you want to limit the amount of tags, 'html()', html_and_css()'
need second argument as hash reference.

    $cloud->html_and_css( { order_by => 'timestamp_desc' , limit => 20 } );

=head2 SORTING TYPE

default is 'name'

=over 4

=item name

=item name_desc

=item count

=item count_desc

=item timestamp

=item timestamp_desc

=back

=head1 OTHER FEATURES

=over 4

=item base_font_size

default size is 24

    # set as constructor's argument
    my $cloud = HTML::TagCloud::Extended->new(
		base_font_size => 30,
	);

    # or you can use accessor.
    $cloud->base_font_size(30);

=item font_size_range

defualt range is 12.

    my $cloud = HTML::TagCloud::Extended->new(
        font_size_range => 10
    );

    $cloud->font_size_range(10);

=item css_class

default name is 'tagcloud'

    my $cloud = HTML::TagCloud::Extended->new(
        css_class => 'mycloud',
    ); 

    $cloud->css_class('mycloud');

=back

=head1 SEE ALSO

L<HTML::TagCloud>

=head1 AUTHOR

Lyo Kato E<lt>lyo.kato@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

This library is free software. You can redistribute it and/or
modify it under the same terms as perl itself.

=cut

