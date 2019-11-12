
/* TapeStub.c : Windows stub to load TAPE2TAP, under Win95.
 *
 * Copyright 1996 Rui Fernando Ferreira Ribeiro.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */


#include <windows.h>
#include <string.h>

char szPath[260] ="";

int PASCAL WinMain(HINSTANCE hinst, HINSTANCE hPrevInst, LPSTR lpCmdLine,
                int nCmdShow)
{
   short i;

   GetModuleFileName(hinst, szPath, sizeof(szPath));
   i = strlen(szPath);
   while(szPath[i] != '\\')
      i--;
   szPath[i] = '\0';

   strcat(szPath, "\\tape2tap.exe" );

   WinExec(szPath, SW_HIDE);
}


/* EOF: TapeStub.c */
