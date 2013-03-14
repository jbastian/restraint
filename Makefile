
CC = gcc
CFLAGS ?= -O -g

PACKAGES = glib-2.0 gobject-2.0 gio-2.0 libxml-2.0 libsoup-2.4 libarchive
CFLAGS += -Wall -Werror -std=c99 $(shell pkg-config --cflags $(PACKAGES))
ifeq ($(STATIC),1)
    # The right thing to do here is `pkg-config --libs --static`, which would 
    # include Libs.private in the link command.
    # But really old pkg-config versions don't understand that so let's just 
    # hardcode the "private" libs here.
    # The -( -) grouping means we don't have to worry about getting all the 
    # dependent libs in the right order (normally pkg-config would do that for 
    # us).
    LIBS = -Wl,-Bstatic -Wl,-\( $(shell pkg-config --libs $(PACKAGES)) -lgmodule-2.0 -llzma -lbz2 -lz -lffi -Wl,-\) -Wl,-Bdynamic -pthread -lrt -lresolv -ldl -lm -lssl
else
    LIBS = $(shell pkg-config --libs $(PACKAGES) $(XTRAPKGS))
endif

.PHONY: all
all: restraint

restraint: main.o recipe.o task.o packages.o fetch_git_task.o param.o role.o
	$(CC) $(LDFLAGS) -o $@ $^ $(LIBS)

fetch_git_task.o: task.h
packages.o: packages.h
task.o: task.h
recipe.o: recipe.h task.h
param.o: param.h
role.o: role.h
main.o: recipe.h task.h
expect_http.o: expect_http.h

TEST_PROGS =
test_%: test_%.o
	$(CC) $(LDFLAGS) -o $@ $^ $(LIBS)

TEST_PROGS += test_packages
test_packages: packages.o
test_packages.o: packages.h

TEST_PROGS += test_task
test_task: task.o packages.o fetch_git_task.o expect_http.o param.o role.o
test_task.o: task.h expect_http.h

test-data/git-remote: test-data/git-remote.tgz
	tar -C test-data -xzf $<

TEST_PROGS += test_recipe
test_recipe: recipe.o task.o packages.o fetch_git_task.o param.o role.o
test_recipe.o: recipe.h task.h param.h

.PHONY: check
check: $(TEST_PROGS) test-data/git-remote
	./run-tests.sh $(TEST_PROGS)

.PHONY: valgrind
valgrind: $(TEST_PROGS) test-data/git-remote
	./run-tests.sh --valgrind $(TEST_PROGS)

.PHONY: clean
clean:
	rm -f restraint $(TEST_PROGS) *.o
