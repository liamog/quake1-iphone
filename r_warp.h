/*
 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version 2
 of the License, or (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
 
 See the GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 
 */

/*
 *  r_warp.h
 *  iPhone Quake
 *
 *  Kevin Arunski, October 2008
 *
 */

#ifndef R_WARP_H
#define R_WARP_H

void EmitWaterPolys (msurface_t *);
void EmitSkyPolys (msurface_t *);
void EmitBothSkyLayers (msurface_t *);
void R_DrawSkyChain (msurface_t *);
void R_MarkLights (dlight_t *light, int bit, mnode_t *node);

#endif
