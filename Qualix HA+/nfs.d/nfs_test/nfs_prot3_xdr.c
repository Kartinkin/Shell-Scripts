/*
 * Please do not edit this file.
 * It was generated using rpcgen.
 */

#include "./nfs_prot3.h"

bool_t
xdr_nfsstat(xdrs, objp)
	register XDR *xdrs;
	nfsstat *objp;
{

	register long *buf;

	if (!xdr_enum(xdrs, (enum_t *)objp))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_ftype(xdrs, objp)
	register XDR *xdrs;
	ftype *objp;
{

	register long *buf;

	if (!xdr_enum(xdrs, (enum_t *)objp))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_nfs_fh(xdrs, objp)
	register XDR *xdrs;
	nfs_fh *objp;
{

	register long *buf;

	int i;
	if (!xdr_opaque(xdrs, objp->data, NFS_FHSIZE))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_nfstime(xdrs, objp)
	register XDR *xdrs;
	nfstime *objp;
{

	register long *buf;

	if (!xdr_u_int(xdrs, &objp->seconds))
		return (FALSE);
	if (!xdr_u_int(xdrs, &objp->useconds))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_fattr(xdrs, objp)
	register XDR *xdrs;
	fattr *objp;
{

	register long *buf;


	if (xdrs->x_op == XDR_ENCODE) {
		if (!xdr_ftype(xdrs, &objp->type))
			return (FALSE);
		buf = XDR_INLINE(xdrs, 10 * BYTES_PER_XDR_UNIT);
		if (buf == NULL) {
			if (!xdr_u_int(xdrs, &objp->mode))
				return (FALSE);
			if (!xdr_u_int(xdrs, &objp->nlink))
				return (FALSE);
			if (!xdr_u_int(xdrs, &objp->uid))
				return (FALSE);
			if (!xdr_u_int(xdrs, &objp->gid))
				return (FALSE);
			if (!xdr_u_int(xdrs, &objp->size))
				return (FALSE);
			if (!xdr_u_int(xdrs, &objp->blocksize))
				return (FALSE);
			if (!xdr_u_int(xdrs, &objp->rdev))
				return (FALSE);
			if (!xdr_u_int(xdrs, &objp->blocks))
				return (FALSE);
			if (!xdr_u_int(xdrs, &objp->fsid))
				return (FALSE);
			if (!xdr_u_int(xdrs, &objp->fileid))
				return (FALSE);

		} else {
			IXDR_PUT_U_LONG(buf, objp->mode);
			IXDR_PUT_U_LONG(buf, objp->nlink);
			IXDR_PUT_U_LONG(buf, objp->uid);
			IXDR_PUT_U_LONG(buf, objp->gid);
			IXDR_PUT_U_LONG(buf, objp->size);
			IXDR_PUT_U_LONG(buf, objp->blocksize);
			IXDR_PUT_U_LONG(buf, objp->rdev);
			IXDR_PUT_U_LONG(buf, objp->blocks);
			IXDR_PUT_U_LONG(buf, objp->fsid);
			IXDR_PUT_U_LONG(buf, objp->fileid);
		}
		if (!xdr_nfstime(xdrs, &objp->atime))
			return (FALSE);
		if (!xdr_nfstime(xdrs, &objp->mtime))
			return (FALSE);
		if (!xdr_nfstime(xdrs, &objp->ctime))
			return (FALSE);
		return (TRUE);
	} else if (xdrs->x_op == XDR_DECODE) {
		if (!xdr_ftype(xdrs, &objp->type))
			return (FALSE);
		buf = XDR_INLINE(xdrs, 10 * BYTES_PER_XDR_UNIT);
		if (buf == NULL) {
			if (!xdr_u_int(xdrs, &objp->mode))
				return (FALSE);
			if (!xdr_u_int(xdrs, &objp->nlink))
				return (FALSE);
			if (!xdr_u_int(xdrs, &objp->uid))
				return (FALSE);
			if (!xdr_u_int(xdrs, &objp->gid))
				return (FALSE);
			if (!xdr_u_int(xdrs, &objp->size))
				return (FALSE);
			if (!xdr_u_int(xdrs, &objp->blocksize))
				return (FALSE);
			if (!xdr_u_int(xdrs, &objp->rdev))
				return (FALSE);
			if (!xdr_u_int(xdrs, &objp->blocks))
				return (FALSE);
			if (!xdr_u_int(xdrs, &objp->fsid))
				return (FALSE);
			if (!xdr_u_int(xdrs, &objp->fileid))
				return (FALSE);

		} else {
			objp->mode = IXDR_GET_U_LONG(buf);
			objp->nlink = IXDR_GET_U_LONG(buf);
			objp->uid = IXDR_GET_U_LONG(buf);
			objp->gid = IXDR_GET_U_LONG(buf);
			objp->size = IXDR_GET_U_LONG(buf);
			objp->blocksize = IXDR_GET_U_LONG(buf);
			objp->rdev = IXDR_GET_U_LONG(buf);
			objp->blocks = IXDR_GET_U_LONG(buf);
			objp->fsid = IXDR_GET_U_LONG(buf);
			objp->fileid = IXDR_GET_U_LONG(buf);
		}
		if (!xdr_nfstime(xdrs, &objp->atime))
			return (FALSE);
		if (!xdr_nfstime(xdrs, &objp->mtime))
			return (FALSE);
		if (!xdr_nfstime(xdrs, &objp->ctime))
			return (FALSE);
		return (TRUE);
	}

	if (!xdr_ftype(xdrs, &objp->type))
		return (FALSE);
	if (!xdr_u_int(xdrs, &objp->mode))
		return (FALSE);
	if (!xdr_u_int(xdrs, &objp->nlink))
		return (FALSE);
	if (!xdr_u_int(xdrs, &objp->uid))
		return (FALSE);
	if (!xdr_u_int(xdrs, &objp->gid))
		return (FALSE);
	if (!xdr_u_int(xdrs, &objp->size))
		return (FALSE);
	if (!xdr_u_int(xdrs, &objp->blocksize))
		return (FALSE);
	if (!xdr_u_int(xdrs, &objp->rdev))
		return (FALSE);
	if (!xdr_u_int(xdrs, &objp->blocks))
		return (FALSE);
	if (!xdr_u_int(xdrs, &objp->fsid))
		return (FALSE);
	if (!xdr_u_int(xdrs, &objp->fileid))
		return (FALSE);
	if (!xdr_nfstime(xdrs, &objp->atime))
		return (FALSE);
	if (!xdr_nfstime(xdrs, &objp->mtime))
		return (FALSE);
	if (!xdr_nfstime(xdrs, &objp->ctime))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_sattr(xdrs, objp)
	register XDR *xdrs;
	sattr *objp;
{

	register long *buf;

	if (!xdr_u_int(xdrs, &objp->mode))
		return (FALSE);
	if (!xdr_u_int(xdrs, &objp->uid))
		return (FALSE);
	if (!xdr_u_int(xdrs, &objp->gid))
		return (FALSE);
	if (!xdr_u_int(xdrs, &objp->size))
		return (FALSE);
	if (!xdr_nfstime(xdrs, &objp->atime))
		return (FALSE);
	if (!xdr_nfstime(xdrs, &objp->mtime))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_filename(xdrs, objp)
	register XDR *xdrs;
	filename *objp;
{

	register long *buf;

	if (!xdr_string(xdrs, objp, NFS_MAXNAMLEN))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_nfspath(xdrs, objp)
	register XDR *xdrs;
	nfspath *objp;
{

	register long *buf;

	if (!xdr_string(xdrs, objp, NFS_MAXPATHLEN))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_attrstat(xdrs, objp)
	register XDR *xdrs;
	attrstat *objp;
{

	register long *buf;

	if (!xdr_nfsstat(xdrs, &objp->status))
		return (FALSE);
	switch (objp->status) {
	case NFS_OK:
		if (!xdr_fattr(xdrs, &objp->attrstat_u.attributes))
			return (FALSE);
		break;
	}
	return (TRUE);
}

bool_t
xdr_sattrargs(xdrs, objp)
	register XDR *xdrs;
	sattrargs *objp;
{

	register long *buf;

	if (!xdr_nfs_fh(xdrs, &objp->file))
		return (FALSE);
	if (!xdr_sattr(xdrs, &objp->attributes))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_diropargs(xdrs, objp)
	register XDR *xdrs;
	diropargs *objp;
{

	register long *buf;

	if (!xdr_nfs_fh(xdrs, &objp->dir))
		return (FALSE);
	if (!xdr_filename(xdrs, &objp->name))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_diropokres(xdrs, objp)
	register XDR *xdrs;
	diropokres *objp;
{

	register long *buf;

	if (!xdr_nfs_fh(xdrs, &objp->file))
		return (FALSE);
	if (!xdr_fattr(xdrs, &objp->attributes))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_diropres(xdrs, objp)
	register XDR *xdrs;
	diropres *objp;
{

	register long *buf;

	if (!xdr_nfsstat(xdrs, &objp->status))
		return (FALSE);
	switch (objp->status) {
	case NFS_OK:
		if (!xdr_diropokres(xdrs, &objp->diropres_u.diropres))
			return (FALSE);
		break;
	}
	return (TRUE);
}

bool_t
xdr_readlinkres(xdrs, objp)
	register XDR *xdrs;
	readlinkres *objp;
{

	register long *buf;

	if (!xdr_nfsstat(xdrs, &objp->status))
		return (FALSE);
	switch (objp->status) {
	case NFS_OK:
		if (!xdr_nfspath(xdrs, &objp->readlinkres_u.data))
			return (FALSE);
		break;
	}
	return (TRUE);
}

bool_t
xdr_readargs(xdrs, objp)
	register XDR *xdrs;
	readargs *objp;
{

	register long *buf;

	if (!xdr_nfs_fh(xdrs, &objp->file))
		return (FALSE);
	if (!xdr_u_int(xdrs, &objp->offset))
		return (FALSE);
	if (!xdr_u_int(xdrs, &objp->count))
		return (FALSE);
	if (!xdr_u_int(xdrs, &objp->totalcount))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_readokres(xdrs, objp)
	register XDR *xdrs;
	readokres *objp;
{

	register long *buf;

	if (!xdr_fattr(xdrs, &objp->attributes))
		return (FALSE);
	if (!xdr_bytes(xdrs, (char **)&objp->data.data_val, (u_int *) &objp->data.data_len, NFS_MAXDATA))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_readres(xdrs, objp)
	register XDR *xdrs;
	readres *objp;
{

	register long *buf;

	if (!xdr_nfsstat(xdrs, &objp->status))
		return (FALSE);
	switch (objp->status) {
	case NFS_OK:
		if (!xdr_readokres(xdrs, &objp->readres_u.reply))
			return (FALSE);
		break;
	}
	return (TRUE);
}

bool_t
xdr_writeargs(xdrs, objp)
	register XDR *xdrs;
	writeargs *objp;
{

	register long *buf;

	if (!xdr_nfs_fh(xdrs, &objp->file))
		return (FALSE);
	if (!xdr_u_int(xdrs, &objp->beginoffset))
		return (FALSE);
	if (!xdr_u_int(xdrs, &objp->offset))
		return (FALSE);
	if (!xdr_u_int(xdrs, &objp->totalcount))
		return (FALSE);
	if (!xdr_bytes(xdrs, (char **)&objp->data.data_val, (u_int *) &objp->data.data_len, NFS_MAXDATA))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_createargs(xdrs, objp)
	register XDR *xdrs;
	createargs *objp;
{

	register long *buf;

	if (!xdr_diropargs(xdrs, &objp->where))
		return (FALSE);
	if (!xdr_sattr(xdrs, &objp->attributes))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_renameargs(xdrs, objp)
	register XDR *xdrs;
	renameargs *objp;
{

	register long *buf;

	if (!xdr_diropargs(xdrs, &objp->from))
		return (FALSE);
	if (!xdr_diropargs(xdrs, &objp->to))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_linkargs(xdrs, objp)
	register XDR *xdrs;
	linkargs *objp;
{

	register long *buf;

	if (!xdr_nfs_fh(xdrs, &objp->from))
		return (FALSE);
	if (!xdr_diropargs(xdrs, &objp->to))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_symlinkargs(xdrs, objp)
	register XDR *xdrs;
	symlinkargs *objp;
{

	register long *buf;

	if (!xdr_diropargs(xdrs, &objp->from))
		return (FALSE);
	if (!xdr_nfspath(xdrs, &objp->to))
		return (FALSE);
	if (!xdr_sattr(xdrs, &objp->attributes))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_nfscookie(xdrs, objp)
	register XDR *xdrs;
	nfscookie objp;
{

	register long *buf;

	if (!xdr_opaque(xdrs, objp, NFS_COOKIESIZE))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_readdirargs(xdrs, objp)
	register XDR *xdrs;
	readdirargs *objp;
{

	register long *buf;

	if (!xdr_nfs_fh(xdrs, &objp->dir))
		return (FALSE);
	if (!xdr_nfscookie(xdrs, objp->cookie))
		return (FALSE);
	if (!xdr_u_int(xdrs, &objp->count))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_entry(xdrs, objp)
	register XDR *xdrs;
	entry *objp;
{

	register long *buf;

	if (!xdr_u_int(xdrs, &objp->fileid))
		return (FALSE);
	if (!xdr_filename(xdrs, &objp->name))
		return (FALSE);
	if (!xdr_nfscookie(xdrs, objp->cookie))
		return (FALSE);
	if (!xdr_pointer(xdrs, (char **)&objp->nextentry, sizeof (entry), (xdrproc_t) xdr_entry))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_dirlist(xdrs, objp)
	register XDR *xdrs;
	dirlist *objp;
{

	register long *buf;

	if (!xdr_pointer(xdrs, (char **)&objp->entries, sizeof (entry), (xdrproc_t) xdr_entry))
		return (FALSE);
	if (!xdr_bool(xdrs, &objp->eof))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_readdirres(xdrs, objp)
	register XDR *xdrs;
	readdirres *objp;
{

	register long *buf;

	if (!xdr_nfsstat(xdrs, &objp->status))
		return (FALSE);
	switch (objp->status) {
	case NFS_OK:
		if (!xdr_dirlist(xdrs, &objp->readdirres_u.reply))
			return (FALSE);
		break;
	}
	return (TRUE);
}

bool_t
xdr_statfsokres(xdrs, objp)
	register XDR *xdrs;
	statfsokres *objp;
{

	register long *buf;


	if (xdrs->x_op == XDR_ENCODE) {
		buf = XDR_INLINE(xdrs, 5 * BYTES_PER_XDR_UNIT);
		if (buf == NULL) {
			if (!xdr_u_int(xdrs, &objp->tsize))
				return (FALSE);
			if (!xdr_u_int(xdrs, &objp->bsize))
				return (FALSE);
			if (!xdr_u_int(xdrs, &objp->blocks))
				return (FALSE);
			if (!xdr_u_int(xdrs, &objp->bfree))
				return (FALSE);
			if (!xdr_u_int(xdrs, &objp->bavail))
				return (FALSE);
		} else {
			IXDR_PUT_U_LONG(buf, objp->tsize);
			IXDR_PUT_U_LONG(buf, objp->bsize);
			IXDR_PUT_U_LONG(buf, objp->blocks);
			IXDR_PUT_U_LONG(buf, objp->bfree);
			IXDR_PUT_U_LONG(buf, objp->bavail);
		}
		return (TRUE);
	} else if (xdrs->x_op == XDR_DECODE) {
		buf = XDR_INLINE(xdrs, 5 * BYTES_PER_XDR_UNIT);
		if (buf == NULL) {
			if (!xdr_u_int(xdrs, &objp->tsize))
				return (FALSE);
			if (!xdr_u_int(xdrs, &objp->bsize))
				return (FALSE);
			if (!xdr_u_int(xdrs, &objp->blocks))
				return (FALSE);
			if (!xdr_u_int(xdrs, &objp->bfree))
				return (FALSE);
			if (!xdr_u_int(xdrs, &objp->bavail))
				return (FALSE);
		} else {
			objp->tsize = IXDR_GET_U_LONG(buf);
			objp->bsize = IXDR_GET_U_LONG(buf);
			objp->blocks = IXDR_GET_U_LONG(buf);
			objp->bfree = IXDR_GET_U_LONG(buf);
			objp->bavail = IXDR_GET_U_LONG(buf);
		}
		return (TRUE);
	}

	if (!xdr_u_int(xdrs, &objp->tsize))
		return (FALSE);
	if (!xdr_u_int(xdrs, &objp->bsize))
		return (FALSE);
	if (!xdr_u_int(xdrs, &objp->blocks))
		return (FALSE);
	if (!xdr_u_int(xdrs, &objp->bfree))
		return (FALSE);
	if (!xdr_u_int(xdrs, &objp->bavail))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_statfsres(xdrs, objp)
	register XDR *xdrs;
	statfsres *objp;
{

	register long *buf;

	if (!xdr_nfsstat(xdrs, &objp->status))
		return (FALSE);
	switch (objp->status) {
	case NFS_OK:
		if (!xdr_statfsokres(xdrs, &objp->statfsres_u.reply))
			return (FALSE);
		break;
	}
	return (TRUE);
}

bool_t
xdr_nfs_fh3(xdrs, objp)
	register XDR *xdrs;
	nfs_fh3 *objp;
{

	register long *buf;

	if (!xdr_bytes(xdrs, (char **)&objp->data.data_val, (u_int *) &objp->data.data_len, NFS3_FHSIZE))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_ftype3(xdrs, objp)
	register XDR *xdrs;
	ftype3 *objp;
{

	register long *buf;

	if (!xdr_enum(xdrs, (enum_t *)objp))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_uint32(xdrs, objp)
	register XDR *xdrs;
	uint32 *objp;
{

	register long *buf;

	if (!xdr_u_long(xdrs, objp))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_uint64(xdrs, objp)
	register XDR *xdrs;
	uint64 *objp;
{

	register long *buf;

	if (!xdr_u_longlong_t(xdrs, objp))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_mode3(xdrs, objp)
	register XDR *xdrs;
	mode3 *objp;
{

	register long *buf;

	if (!xdr_uint32(xdrs, objp))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_uid3(xdrs, objp)
	register XDR *xdrs;
	uid3 *objp;
{

	register long *buf;

	if (!xdr_uint32(xdrs, objp))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_gid3(xdrs, objp)
	register XDR *xdrs;
	gid3 *objp;
{

	register long *buf;

	if (!xdr_uint32(xdrs, objp))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_size3(xdrs, objp)
	register XDR *xdrs;
	size3 *objp;
{

	register long *buf;

	if (!xdr_uint64(xdrs, objp))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_specdata3(xdrs, objp)
	register XDR *xdrs;
	specdata3 *objp;
{

	register long *buf;

	if (!xdr_uint32(xdrs, &objp->specdata1))
		return (FALSE);
	if (!xdr_uint32(xdrs, &objp->specdata2))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_fileid3(xdrs, objp)
	register XDR *xdrs;
	fileid3 *objp;
{

	register long *buf;

	if (!xdr_uint64(xdrs, objp))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_nfstime3(xdrs, objp)
	register XDR *xdrs;
	nfstime3 *objp;
{

	register long *buf;

	if (!xdr_uint32(xdrs, &objp->seconds))
		return (FALSE);
	if (!xdr_uint32(xdrs, &objp->nseconds))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_fattr3(xdrs, objp)
	register XDR *xdrs;
	fattr3 *objp;
{

	register long *buf;

	if (!xdr_ftype3(xdrs, &objp->type))
		return (FALSE);
	if (!xdr_mode3(xdrs, &objp->mode))
		return (FALSE);
	if (!xdr_uint32(xdrs, &objp->nlink))
		return (FALSE);
	if (!xdr_uid3(xdrs, &objp->uid))
		return (FALSE);
	if (!xdr_gid3(xdrs, &objp->gid))
		return (FALSE);
	if (!xdr_size3(xdrs, &objp->size))
		return (FALSE);
	if (!xdr_size3(xdrs, &objp->used))
		return (FALSE);
	if (!xdr_specdata3(xdrs, &objp->rdev))
		return (FALSE);
	if (!xdr_uint64(xdrs, &objp->fsid))
		return (FALSE);
	if (!xdr_fileid3(xdrs, &objp->fileid))
		return (FALSE);
	if (!xdr_nfstime3(xdrs, &objp->atime))
		return (FALSE);
	if (!xdr_nfstime3(xdrs, &objp->mtime))
		return (FALSE);
	if (!xdr_nfstime3(xdrs, &objp->ctime))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_GETATTR3args(xdrs, objp)
	register XDR *xdrs;
	GETATTR3args *objp;
{

	register long *buf;

	if (!xdr_nfs_fh3(xdrs, &objp->object))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_GETATTR3resok(xdrs, objp)
	register XDR *xdrs;
	GETATTR3resok *objp;
{

	register long *buf;

	if (!xdr_fattr3(xdrs, &objp->obj_attributes))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_nfsstat3(xdrs, objp)
	register XDR *xdrs;
	nfsstat3 *objp;
{

	register long *buf;

	if (!xdr_enum(xdrs, (enum_t *)objp))
		return (FALSE);
	return (TRUE);
}

bool_t
xdr_GETATTR3res(xdrs, objp)
	register XDR *xdrs;
	GETATTR3res *objp;
{

	register long *buf;

	if (!xdr_nfsstat3(xdrs, &objp->status))
		return (FALSE);
	switch (objp->status) {
	case NFS3_OK:
		if (!xdr_GETATTR3resok(xdrs, &objp->GETATTR3res_u.resok))
			return (FALSE);
		break;
	}
	return (TRUE);
}