# **DRAFT Specification**

# Introduction

A COPC file is a LAZ 1.4 file that stores point data organized as a cloud optimized octree.

COPC is modeled after the [EPT data format](https://entwine.io/entwine-point-tile.html), but
combines most of the information of an EPT dataset into a single file.  What would be
individual data files in EPT are stored as LAZ chunks in a COPC file. This allows the data to be
consumed by any reader than can handle variably-chunked LAZ 1.4 data. Not all information in
an EPT dataset is currently supported or necessary in a COPC file. More information about the differences
between EPT data and COPC can be found below.

# Notation

Some of the file format is described using C-language
[fixed width integer types](https://en.cppreference.com/w/c/types/integer).
Groups of entities are denoted with a C-language struct, though all data is packed
in the struct and encoded as little-endian values, which may not be the case for
a C program using the same notation.

# Format details

## VLRs (VLR "user ID"/VLR record ID)

### LAZ ("laszip encoded"/22204) [required]

A LAZ encoding VLR whose description is beyond the scope of this document.

### COPC ("entwine"/1) [required]

The COPC VLR data is 80 bytes described by the following data structure.

    struct CopcData
    {
      int64_t span;                 // Number of voxels in each spatial dimension
      uint64_t root_hier_offset;    // File offset to the first hierarchy page
      uint64_t root_hier_size;      // Size of the first hierarchy page in bytes.
      uint64_t reserved[7];         // Reserved for future use.
    };

### WKT/spatial reference ("LASF_Projection"/2112)

If the data can be described by a spatial reference, the file shall also contain a
WKT VLR (GeoTiff VLRs are not supported).

### Extra bytes ("LASF_Spec"/4)

If the data contains "extra bytes" a VLR containing that information shall also be present.

The file may contain additional VLRs if desired.

## Hierarchy

Like EPT, COPC stores hierarchy information to allow a reader to locate points that
are in a particular octree node.  Also like EPT, the hierarchy **may** be arranged in
a tree of pages, but shall always consist of at least one hierarchy page. Hierarchy pages
are contiguous in the data.

The EPT hierarchy data is stored in an extended VLR ("entwine"/1000). The VLR data consists of
one or more hierarchy pages. Each hierarchy data page is written as follows:

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

      // Absolute offset to the data chunk, or absolute offset to a child hierarchy page
      // if the pointCount is -1
      uint64_t offset;

      // Size of the data chunk in bytes (compressed size) or size of the child hierarchy page if
      // the pointCount is -1
      int32_t byteSize;

      // Number of points in the data chunk, or -1 if the information
      // for this octree node and its descendants is contained in other hierarchy pages
      int32_t pointCount;
    }

The entries of a hierarchy page are consecutive. The number of entries in a page can be determined
by taking the size of the page (contained in the parent page as Entry::byteSize or in the COPC base VLR
as CopcData::root_hier_size) and dividing by the size of an Entry (32 bytes)

    struct Page
    {
        Entry entires[page_size / 32];
    };


## Differences from EPT

- COPC has no [ept.json](https://entwine.io/entwine-point-tile.html#ept-data). The information
  from ept.json is stored in the LAS file header and LAS VLRs.
- COPC currently provides no support for
  [ept-sources.json](https://entwine.io/entwine-point-tile.html#ept-sources).
  File metadata support may be added in the future.
- COPC only supports the LAZ point format and does not support binary
  point arrangements.
- COPC chunks store only point data as LAZ. EPT, when stored as LAZ, uses complete
  LAZ files including the LAS header and perhaps VLRs.

# Credits

COPC was designed in July 2021 by Andrew Bell, Howard Butler, and Connor Manning of [Hobu, Inc.](https://hobu.co). Entwine and Entwine Point Tile were also designed and developed by Connor Manning of [Hobu, Inc](https://hobu.co)

# Pronunciation

There is no official pronunciation of COPC. Here are some possible pronunciations ones:

* co-pick – `ko pɪk`
* cop-see – `kap si`
* cop-pick – `kap pɪk`
* see oh pee see – `si o pi si`

# Structural Changes to Draft Specification

* Removed `count` from `Page` struct
* Changed Record ID of COPC hierarchy EVLR from 1234 to 1000

