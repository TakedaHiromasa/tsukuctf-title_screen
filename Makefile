CL65	= cl65
LD65	= ld65

#-------------------------------------------------------------------------------
OUTPUTFILE	=	ctf.nes

CSOURCES	=
ASMSOURCES	=	main.asm
OBJECTS		=	$(CSOURCES:.c=.o) $(ASMSOURCES:.asm=.o)
LIBRARIES	=
#-------------------------------------------------------------------------------
all :	$(OBJECTS) $(LIBRARIES)
	LD65 -o $(OUTPUTFILE) --config main.cfg --obj $(OBJECTS)

.SUFFIXES : .asm .o

.c.o :
	CL65 -t none -o $*.o -c -O $*.c

.asm.o :
	CL65 -t none -o $*.o -c $*.asm

clean :
	rm -f *.smc
	rm -f *.o
	rm -f *.nes