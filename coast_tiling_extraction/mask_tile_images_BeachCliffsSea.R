#Student beach mapping shapes for training of ML beach image identification

#install.packages(c("OpenStreetMap","terra","raster","sf","sp"))

#OpenStreetMap require Java installed #Accesses high resolution raster maps using the OpenStreetMap protocol. Dozens of road, satellite, and topographic map servers are directly supported, including Apple, Mapnik, Bing, and stamen. Additionally raster maps may be constructed using custom tile servers. Maps can beplotted using either base graphics, or ggplot2. This package is not affiliated with the OpenStreetMap.org mapping project.

require(terra)

require(OpenStreetMap)

require(raster) #needed to convert OpenStreetMap to raster

datadir = "/datasets/work/ev-coastal-ml/work/Beach_mapping/data/"

#This dataset has the query points of every beach in Australia
AS_BEACHES_v = vect(paste0(datadir,"ozCoast_beaches_smartline"))


state = "vic"
image_source = "bing"

ress = 1.19
ncols = 512

if(state != "vic") tiles = vect(paste0(datadir,"coast_overlapping_tiles_512_119cm_",state))
if(state == "vic") tiles = vect(paste0(datadir,"coast_overlapping_tiles_512_119cm/coast_overlapping_tiles_512_119cm_manual.shp"))
tiles = tiles[perim(tiles) > 0]
crs(tiles) = "epsg:3857"
tiles_p = project(tiles,"epsg:4326")

OSMBeachShapes = unique(vect(paste0(datadir,"OSM_overpass_student_beach_polygons/Shorts_beaches_CoastSat_OSMBeach_",
                                state,".geojson")))

OSMBeachShapes_v = crop(OSMBeachShapes,ext(tiles_p))
plot(OSMBeachShapes_v)

DEMCliffsShapes = unique(vect(paste0("/datasets/work/ev-ci-cih/work/cliffs/combined/combined_",
                                 toupper(state),".shp")))

coast = as.polygons(vect(paste0("/home/ogr013/notebooks/cihinundation/data/LGA_2023_AUST_GDA2020_coastline")))
coast = vect(paste0("/home/ogr013/notebooks/cihinundation/data/LGA_2023_AUST_GDA2020/LGA_2023_AUST_GDA2020.shp"))
                               
coast = aggregate(crop(coast,ext(tiles_p)))

OSMBeachShapes_v_p = project(OSMBeachShapes_v,"epsg:3857")
DEMCliffsShapes = project(DEMCliffsShapes,"epsg:3857")
coast = project(coast,"epsg:3857")

if(state != "vic") tilefiles= list.files(paste0(datadir,"aerial_beach_images/coast_overlapping_tiles_512_119cm/",state,"/"),full.names = TRUE,pattern = "image_")
if(state == "vic") tilefiles= list.files(paste0(datadir,"aerial_beach_images/coast_overlapping_tiles_512_119cm/"),full.names = TRUE,pattern = "image_")

class_tile_images = function(state = "vic",image_source = "bing",tilefile){
  dir.create(paste0(datadir,"aerial_beach_images/coast_overlapping_tiles_512_119cm/",state))
  dir.create(paste0(datadir,"aerial_beach_images/coast_overlapping_tiles_512_119cm/",state,"/class"))
  tilefile_FID = sub('\\..[^\\.]*$', '', strsplit(basename(tilefile),"_")[[1]][4])
  #osm_ids = FID_2_osm_id$osm_id[FID_2_osm_id$FID == tilefile_FID]
  r = rast(tilefile)
  #map the beaches
  rout_b = rasterize(OSMBeachShapes_v_p,r)*1
  rout_c = rasterize(DEMCliffsShapes,r)*2
  rout_s = rasterize(coast,r)
  rout_s[is.na(rout_s)] = 3
  rout_s[rout_s == 1] = NA
  rout = rout_s
  rout[rout_c == 2] = 2
  rout[rout_b == 1] = 1
  #plot(rout,col = c("yellow","brown","blue"))
  
  outfile = paste0(datadir,"aerial_beach_images/coast_overlapping_tiles_512_119cm/",state,"/class/",image_source,"_",state,"_class_",tilefile_FID,".tif")    
  writeRaster(rout,outfile,overwrite = TRUE)
}


nth = 1
n = length(tilefiles)
x=2225
tilefile = tilefiles[x]
class_tile_images(state = state,image_source = "bing",tilefile = tilefiles[x])
s1 = Sys.time()
lapply((31:n),function(x) class_tile_images(state = state,image_source = "bing",tilefile = tilefiles[x]))
Sys.time()-s1

# the 3526th tile (FID 3691) didn't work, probably because it crosses wgs zones. 





