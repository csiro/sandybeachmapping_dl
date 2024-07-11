#Student beach mapping shapes for training of ML beach image identification

#install.packages(c("OpenStreetMap","terra","raster","sf","sp"))

#OpenStreetMap require Java installed #Accesses high resolution raster maps using the OpenStreetMap protocol. Dozens of road, satellite, and topographic map servers are directly supported, including Apple, Mapnik, Bing, and stamen. Additionally raster maps may be constructed using custom tile servers. Maps can beplotted using either base graphics, or ggplot2. This package is not affiliated with the OpenStreetMap.org mapping project.

require(terra)

require(OpenStreetMap)

require(raster) #needed to convert OpenStreetMap to raster

datadir = "/datasets/work/ev-coastal-ml/work/Beach_mapping/data/"

#This dataset has the query points of every beach in Australia
AS_BEACHES_v = vect(paste0(datadir,"ozCoast_beaches_smartline"))


state = "nsw"
image_source = "bing"

ress = 1.19
ncols = 512

if(state != "vic") tiles = vect(paste0(datadir,"coast_overlapping_tiles_512_119cm_",state))
if(state == "vic") tiles = vect(paste0(datadir,"coast_overlapping_tiles_512_119cm/coast_overlapping_tiles_512_119cm_manual.shp"))
tiles = tiles[perim(tiles) > 0]
crs(tiles) = "epsg:3857"
tiles_p = project(tiles,"epsg:4326")

OSMBeachShapes = unique(vect(paste0(datadir,"OSM_overpass_student_beach_polygons/Shorts_beaches_CoastSat_OSMBeach_"
                                ,state,".geojson")))



OSMBeachShapes_v = crop(OSMBeachShapes,ext(tiles_p))
plot(OSMBeachShapes_v)

OSMBeachShapes_v_p = project(OSMBeachShapes_v,"epsg:3857")

rel = unique(relate(tiles_p,OSMBeachShapes_v, "intersects",pairs = TRUE))

FID_2_osm_id = data.frame(FID = tiles_p$FID[rel[,1]],osm_id = OSMBeachShapes_v$osm_id[rel[,2]])

#split so you have the same number of 
split_FID = 3000
minfun = function(x) abs(length(FID_2_osm_id$FID[FID_2_osm_id$FID > x]) - length(FID_2_osm_id$FID[FID_2_osm_id$FID <= x]))*
                     abs(length(tiles_p$FID[tiles_p$FID > x])           - length(tiles_p$FID[tiles_p$FID <= x]))
optim(3000,minfun,method = "Brent",lower = 100,upper = 8000)

write.csv(FID_2_osm_id,file = paste0(datadir,"aerial_beach_images/coast_overlapping_tiles_512_119cm_FID_2_osm_id_",state,".csv"), quote = FALSE, row.names =FALSE)

which(duplicated(tiles_p$FID[rel[,1]]))

tilefiles= list.files(paste0(datadir,"aerial_beach_images/coast_overlapping_tiles_512_119cm/",state,"/"),full.names = TRUE,pattern = "image_")

mask_tile_images = function(state = "vic",image_source = "bing",tilefile){
  tilefile_FID = sub('\\..[^\\.]*$', '', strsplit(basename(tilefile),"_")[[1]][4])
  #osm_ids = FID_2_osm_id$osm_id[FID_2_osm_id$FID == tilefile_FID]
  r = rast(tilefile)
  #map the beaches
  rout = rasterize(OSMBeachShapes_v_p,r)*2
  if(!all(is.na(values(rout)))){
    rout[is.na(rout)] = 1
    rout[rout == 2] = NA
    #calculate the distance inward
    rdis = distance(rout)
    rdis[rdis == 0] = NA
    rout = rdis
    #plot(rdis)
  }
  outfile = paste0(datadir,"aerial_beach_images/coast_overlapping_tiles_512_119cm/",state,"/",image_source,"_",state,"_mask_",tilefile_FID,".tif")    
  writeRaster(rout,outfile,overwrite = TRUE)
}


nth = 1
n = length(tilefiles)
x=8
mask_tile_images(state = "nsw",image_source = "bing",tilefile = tilefiles[x])
s1 = Sys.time()
lapply((1:n),function(x) mask_tile_images(state = "nsw",image_source = "bing",tilefile = tilefiles[x]))
Sys.time()-s1

# the 3526th tile (FID 3691) didn't work, probably because it crosses wgs zones. 





