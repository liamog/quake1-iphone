//
//  sys_iphone.m
//  iPhone Quake
//
//  Kevin Arunski, October 2008
//
// We fake the file loading into using our writable home directory instead of 
// working on data files alongside the app binary.

#include "quakedef.h"

#define MAX_HANDLES             10
FILE    *sys_handles[MAX_HANDLES];

static int findhandle (void)
{
	int             i;
	
	for (i=1 ; i<MAX_HANDLES ; i++)
		if (!sys_handles[i])
			return i;
	Sys_Error ("out of handles");
	return -1;
}

/*
 ================
 filelength
 ================
 */
static int filelength (FILE *f)
{
	int             pos;
	int             end;
	
	pos = ftell (f);
	fseek (f, 0, SEEK_END);
	end = ftell (f);
	fseek (f, pos, SEEK_SET);
	
	return end;
}

// quake engine reports errors through this interface.
void Sys_Error (char *error, ...)
{
	va_list         argptr;
	va_start (argptr,error);
	[NSException raise:@"Sys_Error" format:[NSString stringWithCString:error] arguments:argptr];
	va_end (argptr);
	
	// default implementation called exit(int) here. Instead, I throw an exception
	// so it can be displayed in the user interface.
}

const char * requestPathToRealPath(const char * requestPath)
{
	// substitute the game directory for the bundle directory
	NSString * bundlePath = [[NSBundle mainBundle] bundlePath];
	return [[bundlePath stringByAppendingPathComponent:[[NSString stringWithCString:requestPath] lastPathComponent]] UTF8String];
}

const char * requestPathToWritablePath(const char * requestPath)
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
	
	// substitute the game directory for the bundle directory
	NSArray * requestPathComponents = [[NSString stringWithCString:requestPath] pathComponents];
	NSUInteger i = 0;
	for (i = 0; i < [requestPathComponents count]; i += 1)
	{
		if ([[requestPathComponents objectAtIndex:i] isEqualToString:[[NSString stringWithCString:com_gamedir] lastPathComponent]])
		{
			break;
		}
	}
	NSMutableArray * newPath = [NSMutableArray arrayWithObjects:documentsDirectory, @"quake", nil];
	if (i < [requestPathComponents count])
	{
		while (i < [requestPathComponents count])
		{
			[newPath addObject:[requestPathComponents objectAtIndex:i]];
			i += 1;
		}
	}
	else
	{
		[newPath addObject:[[NSString stringWithCString:requestPath] lastPathComponent]];
	}
	
	NSString * writeablePath = [NSString pathWithComponents:newPath];
	
	return [writeablePath UTF8String];
}

FILE * Sys_FileOpenStdlib(const char * path, const char * mode)
{
	const char * writePath = requestPathToWritablePath(path);
	if (mode[0] == 'w')
	{
		return fopen(writePath, mode);
	}
	else
	{
		FILE * f = fopen(writePath, "r");
		if (!f)
		{
			const char * readPath = requestPathToRealPath(path);
			f = fopen(readPath, mode);
		}
		return f;
	}
}

int Sys_FileOpenRead (char *path, int *hndl)
{
	FILE    *f;
	int             i;
	
	i = findhandle ();
	
	f = Sys_FileOpenStdlib(path, "rb");
	if (!f)
	{
		*hndl = -1;
		return -1;
	}
	sys_handles[i] = f;
	*hndl = i;
	
	return filelength(f);
}

int Sys_FileOpenWrite (char *path)
{
	FILE    *f;
	int             i;
	
	i = findhandle ();
	
	f = Sys_FileOpenStdlib(path, "wb");
	if (!f)
		Sys_Error ("Error opening %s: %s", path,strerror(errno));
	sys_handles[i] = f;
	
	return i;
}

void Sys_FileClose (int handle)
{
	fclose (sys_handles[handle]);
	sys_handles[handle] = NULL;
}

void Sys_FileSeek (int handle, int position)
{
	fseek (sys_handles[handle], position, SEEK_SET);
}

int Sys_FileRead (int handle, void *dest, int count)
{
	return fread (dest, 1, count, sys_handles[handle]);
}

int Sys_FileWrite (int handle, void *data, int count)
{
	return fwrite (data, 1, count, sys_handles[handle]);
}

int Sys_FileTime (char *path)
{
	FILE    *f;
	
	f = Sys_FileOpenStdlib(path, "rb");
	if (f)
	{
		fclose(f);
		return 1;
	}
	
	return -1;
}

void Sys_mkdir (char *path)
{
	NSFileManager * fileMan = [NSFileManager defaultManager];
	const char * realPath = requestPathToWritablePath(path);
	NSString * realDirPath = [NSString stringWithCString:realPath];
	[fileMan createDirectoryAtPath:realDirPath withIntermediateDirectories:YES attributes:nil error:NULL];
}

