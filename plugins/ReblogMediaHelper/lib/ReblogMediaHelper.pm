package ReblogMediaHelper;

use strict;

# looks like this callback gets called every time reblog reads an entry/item feed node
# for all entries: new, old and modified ones, the entry status isn't available though
sub reblog_entry_parsed {
    my ($cb, $entry, $rb_data, $args) = @_;
    my ($node, $parser, $parser_type) = @{ $args }{ qw/node parser parser_type/ };

    require MT::ObjectAsset;
    my @entry_oa = MT::ObjectAsset->load({
        object_ds => 'entry',
        object_id => $entry->id,
        blog_id   => $entry->blog_id,
    });

    my @new_oa;

    # looking for all media/asset ids inside the entry/item xml:
    #
    #     <media:item>
    #         <media:id>xxx</media:id>
    #         ...
    #     </media:item>
    #     <media:item>
    #         <media:id>xxx</media:id>
    #         ...
    #     </media:item>
    #     ...
    my @mnodes = $parser->findnodes('media:item/media:id', $node);

    foreach my $mnode (@mnodes) {
        my $id = $mnode->string_value;

        # make sure that the asset exists
        require MT::Asset;
        next unless MT::Asset->load($id);

        # just linked
        next if grep { $id eq $_->asset_id } @new_oa;

        # was linked previously
        my ($old_oa) = grep { $id eq $_->asset_id } @entry_oa;
        push(@new_oa, $old_oa), next if $old_oa;

        # creating a new entry-asset link when it's missing
        my $oa = MT::ObjectAsset->new;
        $oa->set_values({
            object_ds => $entry->datasource,
            object_id => $entry->id,
            blog_id   => $entry->blog_id,
            asset_id  => $id,
        });
        $oa->save
            or die 'Error saving object-asset association: ' . $oa->errstr;

        push @new_oa, $oa;
    }

    # deleting old entry-asset links
    foreach my $old_oa (@entry_oa) {
        next if grep { $old_oa->asset_id eq $_->asset_id } @new_oa;

        $old_oa->remove
            or die 'Error removing object-asset association: ' . $old_oa->errstr;
    }
}

1;
