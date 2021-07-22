# COPC – Cloud Optimized Point Cloud

## Use Case

[Cloud Optimized GeoTIFF](https://www.cogeo.org/) has shown the utility and convenience 
of taking a dominant container format for geospatial raster data and optionally 
augmenting its organization to allow incremental "range-read" support over HTTP with it. 
With the mantra of "It's just a TIFF" allowing ubiquitous usage of the data content 
combined with the flexibility of supporting partial reads over the internet, COG has 
found a sweet spot. Its reward is the ongoing rapid conversion of significant raster data 
holdings to COG-organized content to enable convenient cloud consumption of the data 
throughout the GIS industry.

What is the COG for point clouds? It would need to be similar in fit and scope to 
COG:

* Support incremental partial reads over HTTP
* Provide good compression
* Allow dimension-selective reads
* Provide all metadata and supporting information
* Support an [EPT](https://entwine.io/entwine-point-tile.html)-style octree organization for 
  data streaming

## "Just a LAZ"

LAZ (LASZip) is the ubiquitous geospatial point cloud format. It is an augmentation of 
[ASPRS LAS](https://github.com/ASPRSorg/LAS) that utilizes an arithmetic encoder to efficiently 
compress the point content. It has seen a number of revisions, but the latest supports 
dimension-selective access and provides all of the metadata support that normal LAS provides.
Importantly, multiple software implementations ([laz-rs](https://github.com/laz-rs/laz-rs), [laz-perf](https://github.com/hobu/laz-perf), and [LASzip](https://github.com/laszip/laszip)) provide LAZ 
compression and decompression, and laz-perf includes compilation to JavaScript which is 
used by all JavaScript clients when consuming LAZ content. 

## Put EPT in LAZ

The EPT content organization supports LAZ in its current "exploded" organization. Exploded 
in this context means that each chunk of data at each octree level is stored as an individual 
LAZ file (or simple blob, or a zstd-compressed blob). One consequence of the exploded organization 
is large EPT trees of data can mean collections of *millions* of files. In non-cloud situations, 
EPT's cost when moving data or deleting it can be significant. Like the tilesets of late 2000s raster 
map tiles, lots of little files are a problem.

LAZ provides a feature that allows us to concatenate the individual LAZ files
into a single, large LAZ file. This is the concept of a dynamically-sized chunk
table. It is a feature that [Martin Isenburg](https://twitter.com/rapidlasso)
envisioned for quad-tree organized data, but it could work the same for an
octree. Additionally, this chunk table provides the lookups needed for an
HTTP-based client to compute where to directly access and incrementally read
data. 

## Implementation details

Fill in the details of how this all works here

* How is metadata organized and stored?
* Why is it LAZ 1.4 only?
* What about extra dimensions to support preserving scan ordering?
* 

## Software implementations

Which software implements COPC? 
How does it work? 
What options matter are available? 

