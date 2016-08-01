/*
 * Copyright (c) 1996 Qualix Group, Inc. All Rights Reserved.
 *
 * $Id: main.c,v 1.3 1998/01/24 00:14:18 plv Exp $
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

#include "mount.h"
#include "nfs_prot3.h"

static int      program_ver = 2;
static char    *hostname = "localhost";
static char    *file_system = "/";
static fhandle  file_system_handle;
static fhandle3 file_system_handle3;
static int      debug = 0;

static int
parse(int argc, char **argv)
{
    extern char    *optarg;
    extern int      optind;

    const char     *optstring = "v:d";
    int             c;
    int             errflags = 0;
    int             new_program_ver;
    int             i, n;

    while ((c = getopt(argc, argv, optstring)) != EOF) {
	switch (c) {
	case 'v':
	    new_program_ver = atoi(optarg);
	    if ((new_program_ver < 2) || (new_program_ver > 3)) {
		errflags++;
	    } else {
		program_ver = new_program_ver;
	    }
	    break;

	case 'd':
	    debug++;
	    break;

	case '?':
	default:
	    errflags++;
	    break;
	}
    }

    n = 0;
    for (i = optind; i < argc; i++) {
	n++;
    }

    if (n != 2)
	errflags++;
    else {
	hostname = argv[optind];
	file_system = argv[optind + 1];
    }

    return errflags;
}

static void
usage(char *my_name)
{
    fprintf(stderr, "Usage: %s [-v 2 | 3] [-d] hostname file_system\n", my_name);
    fprintf(stderr, "\t-v: NFS version (2 or 3). Default is 2.\n");
    fprintf(stderr, "\t-d: turn on debug flag. Default is 0.\n");
    fprintf(stderr, "\thostname: name of the NFS server. Suggest: localhost.\n");
    fprintf(stderr, "\tfile_system: NFS file system to be tested.\n");
    fprintf(stderr, "For example: %s localhost /\n", my_name);
}

int
print_nfsd_attributes(attrstat * attrp)
{
    if (attrp == (attrstat *) NULL)
	return -1;

    if (attrp->status != NFS_OK)
	return -1;

#define ap (attrp->attrstat_u.attributes)
    printf("{\n");
    printf("  type=%d\n", ap.type);
    printf("  mode=%d\n", ap.mode);
    printf("  nlink=%d\n", ap.nlink);
    printf("  uid=%d\n", ap.uid);
    printf("  gid=%d\n", ap.gid);
    printf("  size=%d\n", ap.size);
    printf("  blocksize=%d\n", ap.blocksize);
    printf("  rdev=%d\n", ap.rdev);
    printf("  blocks=%d\n", ap.blocks);
    printf("  fsid=%d\n", ap.fsid);
    printf("  fileid=%d\n", ap.fileid);
    printf("  atime=%d.%d\n", ap.atime.seconds,
	   ap.atime.useconds);
    printf("  mtime=%d.%d\n", ap.mtime.seconds,
	   ap.mtime.useconds);
    printf("  ctime=%d.%d\n", ap.ctime.seconds,
	   ap.ctime.useconds);
    printf("}\n");
#undef ap

    return 0;
}

int
print_nfsd3_attributes(GETATTR3res * attrp)
{
    if (attrp == (GETATTR3res *) NULL)
	return -1;

    if (attrp->status != NFS3_OK)
	return -1;
#define ap (attrp->GETATTR3res_u.resok.obj_attributes)
    printf("{\n");
    printf("  type=%d\n", ap.type);
    printf("  mode=%d\n", ap.mode);
    printf("  nlink=%d\n", ap.nlink);
    printf("  uid=%d\n", ap.uid);
    printf("  gid=%d\n", ap.gid);
    printf("  size=%d\n", ap.size);
    printf("  used=%d\n", ap.used);
    printf("  rdev=%d.%d\n", ap.rdev.specdata1,
	   ap.rdev.specdata2);
    printf("  fsid=%d\n", ap.fsid);
    printf("  fileid=%d\n", ap.fileid);
    printf("  atime=%d.%d\n", ap.atime.seconds, ap.atime.nseconds);
    printf("  mtime=%d.%d\n", ap.mtime.seconds, ap.mtime.nseconds);
    printf("  ctime=%d.%d\n", ap.ctime.seconds, ap.ctime.nseconds);
    printf("}\n");
#undef ap

    return 0;
}

int
nfs_test_2(void)
{
    CLIENT         *mountd_client;
    void           *mountd_result_1;
    char           *mountproc_null_2_arg;
    fhstatus       *mountd_result_2;
    dirpath         mountproc_mnt_2_arg;

    CLIENT         *nfsd_client;
    void           *nfsd_result_1;
    char           *nfsproc_null_2_arg;
    attrstat       *nfsd_result_2;
    nfs_fh          nfsproc_getattr_2_arg;

    mountd_client = clnt_create(hostname, MOUNTPROG, MOUNTVERS_POSIX, "netpath");
    if (mountd_client == (CLIENT *) NULL) {
	clnt_pcreateerror(hostname);
	return -1;
    }
    /* See if 'mountd' is answering */
    mountd_result_1 = mountproc_null_2((void *) &mountproc_null_2_arg, mountd_client);
    if (mountd_result_1 == (void *) NULL) {
	clnt_perror(mountd_client, "call failed");
	clnt_destroy(mountd_client);
	return -1;
    }
    /* getting a file handle */
    mountproc_mnt_2_arg = file_system;
    mountd_result_2 = mountproc_mnt_2(&mountproc_mnt_2_arg, mountd_client);
    if (mountd_result_2 == (fhstatus *) NULL) {
	clnt_perror(mountd_client, "call failed");
	clnt_destroy(mountd_client);
	return -1;
    } else {
	if (mountd_result_2->fhs_status == 0) {
	    memcpy((void *) &(file_system_handle),
		   (void *) &(mountd_result_2->fhstatus_u.fhs_fhandle),
		   sizeof(fhandle));
	} else {
	    fprintf(stderr, "Cannot mount fs=%s. %s. (Error number = %d).\n",
		    file_system,
		    strerror(mountd_result_2->fhs_status),
		    mountd_result_2->fhs_status);
	    clnt_destroy(mountd_client);
	    return -1;
	}
    }
    /* Done with 'mountd' */
    clnt_destroy(mountd_client);

    /* We have the file handle */
    nfsd_client = clnt_create(hostname, NFS_PROGRAM, NFS_VERSION, "netpath");
    if (nfsd_client == (CLIENT *) NULL) {
	clnt_pcreateerror(hostname);
	return -1;
    }
    /* See if 'nfsd' is answering */
    nfsd_result_1 = nfsproc_null_2((void *) &nfsproc_null_2_arg, nfsd_client);
    if (nfsd_result_1 == (void *) NULL) {
	clnt_perror(nfsd_client, "call failed");
	clnt_destroy(nfsd_client);
	return -1;
    }
    /* get attribute */
    memcpy((void *) &(nfsproc_getattr_2_arg),
	   (void *) &(file_system_handle),
	   sizeof(fhandle));
    nfsd_result_2 = nfsproc_getattr_2(&nfsproc_getattr_2_arg, nfsd_client);
    if (nfsd_result_2 == (attrstat *) NULL) {
	clnt_perror(nfsd_client, "call failed");
	clnt_destroy(nfsd_client);
	return -1;
    } else {
	if (nfsd_result_2->status == NFS_OK) {
	    if (debug) {
		print_nfsd_attributes(nfsd_result_2);
	    }
	} else {
	    fprintf(stderr, "Cannot get attributes for fs=%s. (Error number = %d).\n",
		    file_system,
		    nfsd_result_2->status);
	    clnt_destroy(nfsd_client);
	    return -1;
	}
    }

    clnt_destroy(nfsd_client);

    return 0;
}

int
nfs_test_3(void)
{
    CLIENT         *mountd_client;
    void           *mountd_result_1;
    char           *mountproc_null_3_arg;
    mountres3      *mountd_result_2;
    dirpath         mountproc_mnt_3_arg;

    CLIENT         *nfsd_client;
    void           *nfsd_result_1;
    char           *nfsproc3_null_3_arg;
    GETATTR3res    *nfsd_result_2;
    GETATTR3args    nfsproc3_getattr_3_arg;

    mountd_client = clnt_create(hostname, MOUNTPROG, MOUNTVERS3, "netpath");
    if (mountd_client == (CLIENT *) NULL) {
	clnt_pcreateerror(hostname);
	return -1;
    }
    /* See if 'mountd' is answering */
    mountd_result_1 = mountproc_null_3((void *) &mountproc_null_3_arg, mountd_client);
    if (mountd_result_1 == (void *) NULL) {
	clnt_perror(mountd_client, "call failed");
	clnt_destroy(mountd_client);
	return -1;
    }
    /* getting a file handle */
    mountproc_mnt_3_arg = file_system;
    mountd_result_2 = mountproc_mnt_3(&mountproc_mnt_3_arg, mountd_client);
    if (mountd_result_2 == (mountres3 *) NULL) {
	clnt_perror(mountd_client, "call failed");
	clnt_destroy(mountd_client);
	return -1;
    } else {
	if (mountd_result_2->fhs_status == MNT_OK) {
	    memcpy((void *) &(file_system_handle3),
		 (void *) &(mountd_result_2->mountres3_u.mountinfo.fhandle),
		   sizeof(fhandle3));
	} else {
	    fprintf(stderr, "Cannot mount fs=%s. (Error number = %d).\n",
		    file_system,
		    mountd_result_2->fhs_status);
	    clnt_destroy(mountd_client);
	    return -1;
	}
    }
    /* Done with 'mountd' */
    clnt_destroy(mountd_client);

    /* We have the file handle */
    nfsd_client = clnt_create(hostname, NFS_PROGRAM, NFS_V3, "netpath");
    if (nfsd_client == (CLIENT *) NULL) {
	clnt_pcreateerror(hostname);
	return -1;
    }
    /* See if 'nfsd' is answering */
    nfsd_result_1 = nfsproc3_null_3((void *) &nfsproc3_null_3_arg, nfsd_client);
    if (nfsd_result_1 == (void *) NULL) {
	clnt_perror(nfsd_client, "call failed");
	clnt_destroy(nfsd_client);
	return -1;
    }
    /* get attribute */
    memcpy((void *) &(nfsproc3_getattr_3_arg),
	   (void *) &(file_system_handle3),
	   sizeof(fhandle3));
    nfsd_result_2 = nfsproc3_getattr_3(&nfsproc3_getattr_3_arg, nfsd_client);
    if (nfsd_result_2 == (GETATTR3res *) NULL) {
	clnt_perror(nfsd_client, "call failed");
	clnt_destroy(nfsd_client);
	return -1;
    } else {
	if (nfsd_result_2->status == NFS3_OK) {
	    if (debug) {
		print_nfsd3_attributes(nfsd_result_2);
	    }
	} else {
	    fprintf(stderr, "Cannot get attributes for fs=%s. (Error number = %d).\n",
		    file_system,
		    nfsd_result_2->status);
	    clnt_destroy(nfsd_client);
	    return -1;
	}
    }

    clnt_destroy(nfsd_client);


    return 0;
}

int
main(int argc, char **argv)
{
    if (parse(argc, argv) != 0) {
	usage(argv[0]);
	exit(EXIT_FAILURE);
    }
    memset((void *) &(file_system_handle), '\0', sizeof(fhandle));
    memset((void *) &(file_system_handle3), '\0', sizeof(fhandle3));

    if (program_ver == 2) {
	if (nfs_test_2() != 0) {
	    exit(EXIT_FAILURE);
	}
    } else if (program_ver == 3) {
	if (nfs_test_3() != 0) {
	    exit(EXIT_FAILURE);
	}
    } else {
	usage(argv[0]);
	exit(EXIT_FAILURE);
    }

    exit(EXIT_SUCCESS);
}
