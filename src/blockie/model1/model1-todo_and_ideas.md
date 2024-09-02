# Model 1 Todo and Ideas

## Questions

Question: Do we use the LOD voxel data in the twigs? We should be using it even if it doesn't affect the
performance much it is useful to not have to send so much data to the GPU.

## Twig Optimisation (Breadth first Order)

Instead of writing the twigs in depth first order we could write them breadth first so that the
indexes will only point to twigs in the next layer. This should mean the indexes don't need to be
so large. Test once this has been done because this may have a small effect on the speed.

Once we have breadth first twig layers we can rewrite the twig data. Instead of 12 bytes per twig we can
know the maximum index value for each layer and then we only need to write X bits for each index (instead of
always 24 bits we might only need 16 bits for example). This should reduce the chunk size but may or may not
improve the speed.
