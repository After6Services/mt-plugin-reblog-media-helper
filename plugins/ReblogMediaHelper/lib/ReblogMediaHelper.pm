package ReblogMediaHelper;

use strict;

# looks like this callback gets called every time reblog reads an entry/item feed node
# for all entries: new, old and modified ones, the entry status isn't available though
sub reblog_entry_parsed {
    my ($cb, $entry, $rb_data, $args) = @_;
    my ($node, $parser, $parser_type) = @{ $args }{ qw/node parser parser_type/ };

    # looking for <media:id>123</media:id> inside the entry/item xml
    if ( my $media_id = $parser->findvalue('media:id', $node) ) {
        require MT::ObjectAsset;

        my @entry_assets = MT::ObjectAsset->load({
            object_ds => 'entry',
            object_id => $entry->id,
            blog_id   => $entry->blog_id,
        });

        # creating a new entry-asset link when it's missing
        unless ( grep { $_->asset_id eq $media_id } @entry_assets ) {
            my $oa = MT::ObjectAsset->new;
            $oa->set_values({
                object_ds => $entry->datasource,
                object_id => $entry->id,
                blog_id   => $entry->blog_id,
                asset_id  => $media_id,
            });
            $oa->save
                or die 'Error saving object-asset association: ' . $oa->errstr;
        }

        # deleting all other entry-asset links
        for my $oa ( grep { $_->asset_id ne $media_id } @entry_assets ) {
            $oa->remove
                or die 'Error removing object-asset association: ' . $oa->errstr;
        }
    }
}

1;
