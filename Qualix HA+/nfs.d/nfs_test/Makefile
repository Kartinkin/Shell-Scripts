#
# Copyright (c) 1996 Qualix Group, Inc. All Rights Reserved.
#
# $Id: Makefile,v 1.7 1998/01/24 00:14:14 plv Exp $
#
#

TOPDIR = ../../../../..

include $(TOPDIR)/Makefile.cprogs


CFLAGS =

LIBS = $(LIBSOC)

SRCS = \
  mount_clnt.c \
  mount_xdr.c \
  nfs_prot3_clnt.c \
  nfs_prot3_xdr.c \
  main.c

OBJS = ${SRCS:.c=.o}

PROG = nfs_test

ifdef SOL
all: ${PROG}
endif
ifdef HPUX
all:
	@echo Nothing happens!
endif

nfs_test: ${OBJS}
	$(do_ld)

clean: stdclean
	-${RM} ${PROG}

depend: ; $(do_depend)

ifdef deps
include $(SRCS:.c=.dep)
endif
