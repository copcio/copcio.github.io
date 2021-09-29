# ***DRAFT*** Cloud Optimized Point Cloud Specification – 1.0 **DRAFT***

![COPC Logo](COPC_IO-Logo-2color.png)

# Table of contents
1. [Version](#version)
2. [Introduction](#introduction)
3. [Notation](#notation)
4. [Implementation](#implementation)
    1. [LAS PDRF 6, 7, or 8](#las-pdrfs-6-7-or-8)
    2. [``info`` VLR](#info-vlr)
    3. [``hierarchy`` VLR](#hierarchy-vlr)
    4. [``extents`` VLR](#extents-vlr)
    5. [LAS PDRF 6, 7, or 8](#las-pdrfs-6-7-or-8)
    6. [LAZ VLR](#laz-vlr)
    7. [Spatial reference VLR](#spatial-reference-vlr)
    8. [Extra bytes VLR](#extra-bytes-vlr)
    9. [Versioning](#versioning)
5. [Differences from EPT](#differences-from-ept)
6. [Example Data](#example-data)
7. [Reader Implementation Nodes](#reader-implementation-notes)
8. [Credits](#credits)
9. [Pronunciation](#pronunciation)
10. [Discussion](#discussion)
11. [Structural Changes to Draft Specification](#structural-changes-to-draft-specification)


# Version

This document defines Cloud Optimized Point Cloud (COPC) version **1.0**.

# Introduction

A COPC file is a LAZ 1.4 file that stores point data organized in a clustered
octree. It does this by providing some VLRs and using the variable chunking
strategy of LAZ 1.4.

Data organization of COPC is modeled after the [EPT data
format](https://entwine.io/entwine-point-tile.html), but COPC clusters the
storage of the octree as variably-chunked LAZ data in a single file.  This
allows the data to be consumed by any reader than can handle variably-chunked
LAZ 1.4 (most LASzip-based implementations). Not all information in an EPT
dataset is currently supported or necessary in a COPC file. More information
about the differences between EPT data and COPC can be found below.

# Notation

Some of the file format is described using C-language [fixed width integer
types](https://en.cppreference.com/w/c/types/integer).  Groups of entities are
denoted with a C-language struct, though all data is packed in the struct and
encoded as little-endian values, which may not be the case for a C program
using the same notation.

# Implementation

Key aspects distinguish an organized COPC LAZ file from an LAZ 1.4 that is unorganized:

* It *MUST* contain *ONLY* LAS PDRFs 6, 7, or 8 formatted data
* It *MUST* contain a COPC ``info`` VLR
* It *MUST* contain a COPC ``hierarchy`` VLR
* It *MUST* contain a COPC ``extents`` VLR
* It *MUST* be stored as LAZ 1.4 (no "compatibility" mode)
* It *MUST* contain OGC WKTv1 VLR if the data has a spatial reference


## LAS PDRFs 6, 7, or 8

COPC files *MUST* contain data with *ONLY* ASPRS LAS Point Data Record Format 6, 7, or 8. See
the [ASPRS LAS specification](https://github.com/ASPRSorg/LAS) for details.

## ``info`` VLR

| User ID                    | Record ID        |
| -------------------------- | ---------------- |
| ``copc``                   | ``1``            |

The ``info`` VLR *MUST* exist.

The ``info`` VLR *MUST* be the **first** VLR in the file after the header.

The ``info`` VLR *MAY* be used by software clients to know the details of the
``hierarchy`` VLR.

The ``info`` VLR is ``160`` bytes described by the following structure.
``reserved`` elements *MUST* be set to ``0``.

    struct CopcInfo
    {

      // X coordinate of center of octree
      double center_x;

      // Y coordinate of center of octree
      double center_y;

      // Z coordinate of center of octree
      double center_z;

      // halfsize of octree.
      double halfsize;

      // Space between points at the root node.
      // This value is halved at each octree level
      double spacing;

      // Reserved for future use. Must be 0.
      uint64_t reserved[15];
    };



## ``hierarchy`` VLR

| User ID                    | Record ID        |
| -------------------------- | ---------------- |
| ``copc``                   | ``1000``         |

The ``hierarchy`` VLR *MUST* exist.

Like EPT, COPC stores hierarchy information to allow a reader to locate points
that are in a particular octree node.  Also like EPT, the hierarchy *MAY* be
arranged in a tree of pages, but shall always consist of at least ONE hierarchy
page. Hierarchy pages are contiguous in the data.

The VLR data consists of one or more hierarchy pages. Each hierarchy data page
is written as follows:

The VoxelKey corresponds to the naming of
[EPT data files](https://entwine.io/entwine-point-tile.html#ept-data).

    struct VoxelKey
    {
      // A value < 0 indicates an invalid VoxelKey
      int32_t level;
      int32_t x;
      int32_t y;
      int32_t z;
    };

An entry corresponds to a single key/value pair in an
[EPT hierarchy](https://entwine.io/entwine-point-tile.html#ept-data),
but contains additional information to allow direct access and decoding of the corresponding
point data.

    struct Entry
    {
      // EPT key of the data to which this entry corresponds
      VoxelKey key;

      // Absolute offset to the data chunk if the pointCount > 0.
      // Absolute offset to a child hierarchy page if the pointCount is -1.
      // 0 if the pointCount is 0.
      uint64_t offset;

      // Size of the data chunk in bytes (compressed size) if the pointCount > 0.
      // Size of the hierarchy page if the pointCount is -1.
      // 0 if the pointCount is 0.
      int32_t byteSize;

      // If > 0, represents the number of points in the data chunk.
      // If -1, indicates the information for this octree node is found in another hierarchy page.
      // If 0, no point data exists for this key, though may exist for child entries.
      int32_t pointCount;
    }


The entries of a hierarchy page are consecutive. The number of entries in a
page can be determined by taking the size of the page (contained in the parent
page as ``Entry::byteSize`` or in the COPC ``info`` VLR as
``CopcData::root_hier_size``) and dividing by the size of an ``Entry`` (32
bytes).

    struct Page
    {
        Entry entries[page_size / 32];
    };


## ``extents`` VLR

| User ID                    | Record ID        |
| -------------------------- | ---------------- |
| ``copc``                   | ``10000``        |

Minimal statistics about *EACH* dimension *MUST* be provided by the COPC ``extents`` VLR.



    struct CopcExtent
    {
        double minimum;
        double maximum;
    }


### Ordering

The VLR body *MUST* contain a ``CopcExtent`` entry for each dimension. including X,
Y, and Z, whose stats are in the LAS header, *AND* ``CopcExtent`` entries for
each [Extra bytes Dimension](extra-bytes-VLR).


| Dimension Name | Position | PDRF |
| :-- | :--: | :--: |
| X | 0 | 6, 7, 8 |
| Y | 1 | 6, 7, 8 |
| Z | 2 | 6, 7, 8 |
| Intensity | 3 | 6, 7, 8 |
| Return Number | 4 | 6, 7, 8 |
| Number of Returns | 5 | 6, 7, 8 |
| Scanner Channel | 6 | 6, 7, 8 |
| Scan Direction Flag | 7 | 6, 7, 8 |
| Edge of Flight Line | 8 | 6, 7, 8 |
| Classification | 9 | 6, 7, 8 |
| User Data | 10  | 6, 7, 8 |
| Scan Angle | 11 | 6, 7, 8 |
| Point Source ID | 12 | 6, 7, 8 |
| GPS Time | 13 | 6, 7, 8 |
| Red | 14 |  7, 8 |
| Green | 15 |  7, 8 |
| Blue | 16 |  7, 8 |
| Infrared | 17 |  8 |


### Extra bytes

Each extra bytes item *MUST* contain corresponding ``CopcExtent`` item in the
order defined by the [Extra bytes VLR](extra-bytes-vlr).


## LAZ VLR

| User ID                    | Record ID        |
| -------------------------- | ---------------- |
| ``laszip encoded``         | ``22204``        |

The LAZ VLR *MUST* exist. A LAZ encoding VLR whose description is beyond the
scope of this document.


## Spatial reference VLR

| User ID                    | Record ID        |
| -------------------------- | ---------------- |
| ``LASF_Projection``        | ``2112``         |

The spatial reference VLR *MAY* exist.

COPC clients are not expected to consume GeoTIFF VLRs, although
their presence is allowed.

## Extra bytes VLR

| User ID        | Record ID        |
| -------------- | ---------------- |
| ``LASF_Spec``  | ``4``            |

An Extra Bytes VLR containing that information *MUST* be present
if extra per-point data is provided.

## Versioning

Should any future incremental versioning of COPC occur, is expected to utilize VLR
definitions with incremented ``Record ID`` values as the discrimination mechanism. It *MAY*
be possible to write COPC data with simultaneous definitions of `info`, `hierarchy` or `extents`
VLRs as needed to support future needs.

# Differences from EPT

* COPC has no [ept.json](https://entwine.io/entwine-point-tile.html#ept-data). The information
  from ept.json is stored in the LAS file header and LAS VLRs.
* COPC currently provides no support for
  [ept-sources.json](https://entwine.io/entwine-point-tile.html#ept-sources).
  File metadata support may be added in the future.
* COPC only supports the LAZ point format and does not support binary
  point arrangements.
* COPC chunks store only point data as LAZ. EPT, when stored as LAZ, uses complete
  LAZ files including the LAS header and perhaps VLRs.

# Example Data

* The venerable [Autzen
  Stadium](https://github.com/PDAL/data/tree/master/autzen) file commonly used
  in PDAL and other open source testing scenarios is available as a 80mb COPC
  file at
  [https://github.com/PDAL/data/blob/master/autzen/autzen-classified.copc.laz](https://github.com/PDAL/data/blob/master/autzen/autzen-classified.copc.laz)

* SoFi Stadium is available as a 2.3gb COPC file at
  [https://hobu-lidar.s3.amazonaws.com/sofi.copc.laz](https://hobu-lidar.s3.amazonaws.com/sofi.copc.laz).
  The data are courtesy of [US Army Corps of Engineers Remote Sensing & GIS
  Center of Expertise](https://www.erdc.usace.army.mil/Locations/CRREL/) /
  [National Center for Airborne Laser Mapping](http://ncalm.cive.uh.edu/)

# Reader Implementation Nodes

COPC is designed so that a reader needs to know little about the structure of a LAZ file.
By reading the first 549 bytes (375 for the header + 54 for the COPC VLR header + 160
for the COPC VLR), the software can verify that the file is a COPC file and determine
the point data record format and point data record length, both of which are necessary
to create a LAZ decompressor.

Readers should:
* verify that the first four bytes of the file contain the ASCII characters "LASF".
* verify that the 7 bytes starting offset 377 contain the characters `copc`.
* verify that the bytes at offsets 393 and 394 contain the values 1 and 0,
  respectively (this is the COPC version number, 1).
* determine the point data record format by reading the byte at offset 104, masking off the
  two high bits, which are used by LAZ to indicate compression, and can be ignored.
* determine the point data record length by reading two bytes at offset 105.

The octree hierarchy is arranged in pages. The COPC VLR provides information pointing to
root page. When reading data from a network connection, information in each page will
be used to traverse to child pages.  Each entry in a hierarchy page either refers to a
child hierarchy page or a data chunk. The size and file offset of each data chunk is
provided in the hierarchy entries, allowing the chunks to be directly read for decoding.

# Credits

COPC was designed in July–September 2021 by Andrew Bell, Howard Butler, and Connor
Manning of [Hobu, Inc.](https://hobu.co). [Entwine](https://entwine.io) and
[Entwine Point Tile](https://entwine.io/entwine-point-tile.html) were also
designed and developed by Connor Manning of [Hobu, Inc](https://hobu.co)

# Pronunciation

There is no official pronunciation of COPC. Here are some possibilities:

* co-pick – `ko pIk`
* cop-see – `kap si`
* cop-pick – `kap pIk`
* see oh pee see – `si o pi si`

# Discussion

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

LAZ (LASZip) is the ubiquitous geospatial point cloud format. It is an
augmentation of [ASPRS LAS](https://github.com/ASPRSorg/LAS) that utilizes an
arithmetic encoder to efficiently compress the point content. It has seen a
number of revisions, but the latest supports dimension-selective access and
provides all of the metadata support that normal LAS provides.  Importantly,
multiple software implementations ([laz-rs](https://github.com/laz-rs/laz-rs),
[laz-perf](https://github.com/hobu/laz-perf), and
[LASzip](https://github.com/laszip/laszip)) provide LAZ compression and
decompression, and laz-perf and laz-rs include compilation to JavaScript which
is used by all JavaScript clients when consuming LAZ content.

## Put EPT in LAZ

The EPT content organization supports LAZ in its current "exploded"
organization. Exploded in this context means that each chunk of data at each
octree level is stored as an individual LAZ file (or simple blob, or a
zstd-compressed blob). One consequence of the exploded organization is large
EPT trees of data can mean collections of *millions* of files. In non-cloud
situations, EPT's cost when moving data or deleting it can be significant. Like
the tilesets of late 2000s raster map tiles, lots of little files are a
problem.

LAZ provides a feature that allows us to concatenate the individual LAZ files
into a single, large LAZ file. This is the concept of a dynamically-sized chunk
table. It is a feature that [Martin Isenburg](https://twitter.com/rapidlasso)
envisioned for quad-tree organized data, but it could work the same for an
octree. Additionally, this chunk table provides the lookups needed for an
HTTP-based client to compute where to directly access and incrementally read
data.

# Structural Changes to Draft Specification

* Removed `count` from `Page` struct
* Changed Record ID of COPC hierarchy EVLR from 1234 to 1000
* Require reserved entries of the COPC VLR to have the value 0
* Require the COPC VLR to be located immediately after the header at offset 375.
* Increase the size of the COPC VLR data structure to 160 bytes.
* Add `laz_vlr_offset`, `laz_vlr_size`, `wkt_vlr_offset`, `wkt_vlr_size`,
  `eb_vlr_offset`, `eb_vlr_size` to the COPC VLR, replacing 6 `reserved` entries.
* PDRF must be 6, 7, or 8
* Add `extents` VLR.
* VLR UserIDs switched from `entwine` to `copc`
* Removed offsets in `info` VLR.
* Describe hierarchy entries for empty octree nodes.
