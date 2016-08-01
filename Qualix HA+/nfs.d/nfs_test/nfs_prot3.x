/*
 *
 *#ident "@(#)nfs_prot.x 1.1 89/08/09 SMI"
 * nfs_prot.x 1.3 88/02/08
 * Copyright 1987 Sun Microsystems, Inc.
 */
const NFS_PORT          = 2049;
const NFS_MAXDATA       = 8192;
const NFS_MAXPATHLEN    = 1024;
const NFS_MAXNAMLEN	= 255;
const NFS_FHSIZE	= 32;
const NFS_COOKIESIZE	= 4;
const NFS_FIFO_DEV	= -1;	/* size kludge for named pipes */

/*
 * File types
 */
const NFSMODE_FMT  = 0170000;	/* type of file */
const NFSMODE_DIR  = 0040000;	/* directory */
const NFSMODE_CHR  = 0020000;	/* character special */
const NFSMODE_BLK  = 0060000;	/* block special */
const NFSMODE_REG  = 0100000;	/* regular */
const NFSMODE_LNK  = 0120000;	/* symbolic link */
const NFSMODE_SOCK = 0140000;	/* socket */
const NFSMODE_FIFO = 0010000;	/* fifo */

/*
 * Error status
 */
enum nfsstat {
	NFS_OK= 0,		/* no error */
	NFSERR_PERM=1,		/* Not owner */
	NFSERR_NOENT=2,		/* No such file or directory */
	NFSERR_IO=5,		/* I/O error */
	NFSERR_NXIO=6,		/* No such device or address */
	NFSERR_ACCES=13,	/* Permission denied */
	NFSERR_EXIST=17,	/* File exists */
	NFSERR_NODEV=19,	/* No such device */
	NFSERR_NOTDIR=20,	/* Not a directory*/
	NFSERR_ISDIR=21,	/* Is a directory */
	NFSERR_FBIG=27,		/* File too large */
	NFSERR_NOSPC=28,	/* No space left on device */
	NFSERR_ROFS=30,		/* Read-only file system */
	NFSERR_NAMETOOLONG=63,	/* File name too long */
	NFSERR_NOTEMPTY=66,	/* Directory not empty */
	NFSERR_DQUOT=69,	/* Disc quota exceeded */
	NFSERR_STALE=70,	/* Stale NFS file handle */
	NFSERR_WFLUSH=99	/* write cache flushed */
};

/*
 * File types
 */
enum ftype {
	NFNON = 0,	/* non-file */
	NFREG = 1,	/* regular file */
	NFDIR = 2,	/* directory */
	NFBLK = 3,	/* block special */
	NFCHR = 4,	/* character special */
	NFLNK = 5,	/* symbolic link */
	NFSOCK = 6,	/* unix domain sockets */
	NFBAD = 7,	/* unused */
	NFFIFO = 8 	/* named pipe */
};

/*
 * File access handle
 */
struct nfs_fh {
	opaque data[NFS_FHSIZE];
};

/* 
 * Timeval
 */
struct nfstime {
	unsigned seconds;
	unsigned useconds;
};


/*
 * File attributes
 */
struct fattr {
	ftype type;		/* file type */
	unsigned mode;		/* protection mode bits */
	unsigned nlink;		/* # hard links */
	unsigned uid;		/* owner user id */
	unsigned gid;		/* owner group id */
	unsigned size;		/* file size in bytes */
	unsigned blocksize;	/* prefered block size */
	unsigned rdev;		/* special device # */
	unsigned blocks;	/* Kb of disk used by file */
	unsigned fsid;		/* device # */
	unsigned fileid;	/* inode # */
	nfstime	atime;		/* time of last access */
	nfstime	mtime;		/* time of last modification */
	nfstime	ctime;		/* time of last change */
};

/*
 * File attributes which can be set
 */
struct sattr {
	unsigned mode;	/* protection mode bits */
	unsigned uid;	/* owner user id */
	unsigned gid;	/* owner group id */
	unsigned size;	/* file size in bytes */
	nfstime	atime;	/* time of last access */
	nfstime	mtime;	/* time of last modification */
};


typedef string filename<NFS_MAXNAMLEN>; 
typedef string nfspath<NFS_MAXPATHLEN>;

/*
 * Reply status with file attributes
 */
union attrstat switch (nfsstat status) {
case NFS_OK:
	fattr attributes;
default:
	void;
};

struct sattrargs {
	nfs_fh file;
	sattr attributes;
};

/*
 * Arguments for directory operations
 */
struct diropargs {
	nfs_fh	dir;	/* directory file handle */
	filename name;		/* name (up to NFS_MAXNAMLEN bytes) */
};

struct diropokres {
	nfs_fh file;
	fattr attributes;
};

/*
 * Results from directory operation
 */
union diropres switch (nfsstat status) {
case NFS_OK:
	diropokres diropres;
default:
	void;
};

union readlinkres switch (nfsstat status) {
case NFS_OK:
	nfspath data;
default:
	void;
};

/*
 * Arguments to remote read
 */
struct readargs {
	nfs_fh file;		/* handle for file */
	unsigned offset;	/* byte offset in file */
	unsigned count;		/* immediate read count */
	unsigned totalcount;	/* total read count (from this offset)*/
};

/*
 * Status OK portion of remote read reply
 */
struct readokres {
	fattr	attributes;	/* attributes, need for pagin*/
	opaque data<NFS_MAXDATA>;
};

union readres switch (nfsstat status) {
case NFS_OK:
	readokres reply;
default:
	void;
};

/*
 * Arguments to remote write 
 */
struct writeargs {
	nfs_fh	file;		/* handle for file */
	unsigned beginoffset;	/* beginning byte offset in file */
	unsigned offset;	/* current byte offset in file */
	unsigned totalcount;	/* total write count (to this offset)*/
	opaque data<NFS_MAXDATA>;
};

struct createargs {
	diropargs where;
	sattr attributes;
};

struct renameargs {
	diropargs from;
	diropargs to;
};

struct linkargs {
	nfs_fh from;
	diropargs to;
};

struct symlinkargs {
	diropargs from;
	nfspath to;
	sattr attributes;
};


typedef opaque nfscookie[NFS_COOKIESIZE];

/*
 * Arguments to readdir
 */
struct readdirargs {
	nfs_fh dir;		/* directory handle */
	nfscookie cookie;
	unsigned count;		/* number of directory bytes to read */
};

struct entry {
	unsigned fileid;
	filename name;
	nfscookie cookie;
	entry *nextentry;
};

struct dirlist {
	entry *entries;
	bool eof;
};

union readdirres switch (nfsstat status) {
case NFS_OK:
	dirlist reply;
default:
	void;
};

struct statfsokres {
	unsigned tsize;	/* preferred transfer size in bytes */
	unsigned bsize;	/* fundamental file system block size */
	unsigned blocks;	/* total blocks in file system */
	unsigned bfree;	/* free blocks in fs */
	unsigned bavail;	/* free blocks avail to non-superuser */
};

union statfsres switch (nfsstat status) {
case NFS_OK:
	statfsokres reply;
default:
	void;
};


/* Version 3 */
const FS3_FHSIZE = 64;
const NFS3_FHSIZE = 64;

struct nfs_fh3 {
	opaque       data<NFS3_FHSIZE>;
};

enum ftype3 {
         NF3REG    = 1,
         NF3DIR    = 2,
         NF3BLK    = 3,
         NF3CHR    = 4,
         NF3LNK    = 5,
         NF3SOCK   = 6,
         NF3FIFO   = 7
};

typedef unsigned long uint32;
typedef unsigned hyper uint64;
typedef uint32 mode3;
typedef uint32 uid3;
typedef uint32 gid3;
typedef uint64 size3;
struct specdata3 {
           uint32     specdata1;
           uint32     specdata2;
};
typedef uint64 fileid3;

struct nfstime3 {
         uint32   seconds;
         uint32   nseconds;
};

struct fattr3 {
         ftype3     type;
         mode3      mode;
         uint32     nlink;
         uid3       uid;
         gid3       gid;
         size3      size;
         size3      used;
         specdata3  rdev;
         uint64     fsid;
         fileid3    fileid;
         nfstime3   atime;
         nfstime3   mtime;
         nfstime3   ctime;
};

struct GETATTR3args {
         nfs_fh3  object;
};

struct GETATTR3resok {
         fattr3   obj_attributes;
};

enum nfsstat3 {
         NFS3_OK             = 0,
         NFS3ERR_PERM        = 1,
         NFS3ERR_NOENT       = 2,
         NFS3ERR_IO          = 5,
         NFS3ERR_NXIO        = 6,
         NFS3ERR_ACCES       = 13,
         NFS3ERR_EXIST       = 17,
         NFS3ERR_XDEV        = 18,
         NFS3ERR_NODEV       = 19,
         NFS3ERR_NOTDIR      = 20,
         NFS3ERR_ISDIR       = 21,
         NFS3ERR_INVAL       = 22,
         NFS3ERR_FBIG        = 27,
         NFS3ERR_NOSPC       = 28,
         NFS3ERR_ROFS        = 30,
         NFS3ERR_MLINK       = 31,
         NFS3ERR_NAMETOOLONG = 63,
         NFS3ERR_NOTEMPTY    = 66,
         NFS3ERR_DQUOT       = 69,
         NFS3ERR_STALE       = 70,
         NFS3ERR_REMOTE      = 71,
         NFS3ERR_BADHANDLE   = 10001,
         NFS3ERR_NOT_SYNC    = 10002,
         NFS3ERR_BAD_COOKIE  = 10003,
         NFS3ERR_NOTSUPP     = 10004,
         NFS3ERR_TOOSMALL    = 10005,
         NFS3ERR_SERVERFAULT = 10006,
         NFS3ERR_BADTYPE     = 10007,
         NFS3ERR_JUKEBOX     = 10008
};

union GETATTR3res switch (nfsstat3 status) {
	case NFS3_OK:
         GETATTR3resok  resok;
      	default:
         void;
};

/*
 * Remote file service routines
 */
program NFS_PROGRAM {
	version NFS_VERSION {
		void 
		NFSPROC_NULL(void) = 0;

		attrstat 
		NFSPROC_GETATTR(nfs_fh) =	1;

		attrstat 
		NFSPROC_SETATTR(sattrargs) = 2;

		void 
		NFSPROC_ROOT(void) = 3;

		diropres 
		NFSPROC_LOOKUP(diropargs) = 4;

		readlinkres 
		NFSPROC_READLINK(nfs_fh) = 5;

		readres 
		NFSPROC_READ(readargs) = 6;

		void 
		NFSPROC_WRITECACHE(void) = 7;

		attrstat
		NFSPROC_WRITE(writeargs) = 8;

		diropres
		NFSPROC_CREATE(createargs) = 9;

		nfsstat
		NFSPROC_REMOVE(diropargs) = 10;

		nfsstat
		NFSPROC_RENAME(renameargs) = 11;

		nfsstat
		NFSPROC_LINK(linkargs) = 12;

		nfsstat
		NFSPROC_SYMLINK(symlinkargs) = 13;

		diropres
		NFSPROC_MKDIR(createargs) = 14;

		nfsstat
		NFSPROC_RMDIR(diropargs) = 15;

		readdirres
		NFSPROC_READDIR(readdirargs) = 16;

		statfsres
		NFSPROC_STATFS(nfs_fh) = 17;
	} = 2;

	version NFS_V3 {
            	void
             	NFSPROC3_NULL(void)                    = 0;

            	GETATTR3res
             	NFSPROC3_GETATTR(GETATTR3args)         = 1;

#if 0
            	SETATTR3res
             	NFSPROC3_SETATTR(SETATTR3args)         = 2;

            	LOOKUP3res
             	NFSPROC3_LOOKUP(LOOKUP3args)           = 3;

            	ACCESS3res
             	NFSPROC3_ACCESS(ACCESS3args)           = 4;

            	READLINK3res
             	NFSPROC3_READLINK(READLINK3args)       = 5;

            	READ3res
             	NFSPROC3_READ(READ3args)               = 6;

            	WRITE3res
             	NFSPROC3_WRITE(WRITE3args)             = 7;

            	CREATE3res
             	NFSPROC3_CREATE(CREATE3args)           = 8;

            	MKDIR3res
             	NFSPROC3_MKDIR(MKDIR3args)             = 9;

            	SYMLINK3res
             	NFSPROC3_SYMLINK(SYMLINK3args)         = 10;

            	MKNOD3res
             	NFSPROC3_MKNOD(MKNOD3args)             = 11;

            	REMOVE3res
             	NFSPROC3_REMOVE(REMOVE3args)           = 12;

            	RMDIR3res
             	NFSPROC3_RMDIR(RMDIR3args)             = 13;

            	RENAME3res
             	NFSPROC3_RENAME(RENAME3args)           = 14;

            	LINK3res
             	NFSPROC3_LINK(LINK3args)               = 15;

            	READDIR3res
             	NFSPROC3_READDIR(READDIR3args)         = 16;

            	READDIRPLUS3res
             	NFSPROC3_READDIRPLUS(READDIRPLUS3args) = 17;

            	FSSTAT3res
             	NFSPROC3_FSSTAT(FSSTAT3args)           = 18;

            	FSINFO3res
             	NFSPROC3_FSINFO(FSINFO3args)           = 19;

            	PATHCONF3res
             	NFSPROC3_PATHCONF(PATHCONF3args)       = 20;

            	COMMIT3res
             	NFSPROC3_COMMIT(COMMIT3args)           = 21;
#endif
         } = 3;
} = 100003;
