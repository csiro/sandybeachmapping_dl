#Student beach mapping shapes for training of ML beach image identification

#install.packages(c("OpenStreetMap","terra","raster","sf","sp"))

#OpenStreetMap require Java installed #Accesses high resolution raster maps using the OpenStreetMap protocol. Dozens of road, satellite, and topographic map servers are directly supported, including Apple, Mapnik, Bing, and stamen. Additionally raster maps may be constructed using custom tile servers. Maps can beplotted using either base graphics, or ggplot2. This package is not affiliated with the OpenStreetMap.org mapping project.

require(terra)

require(OpenStreetMap)

require(raster) #needed to convert OpenStreetMap to raster

datadir = "/datasets/work/ev-coastal-ml/work/Beach_mapping/data/"

#This dataset has the query points of every beach in Australia
AS_BEACHES_v = vect(paste0(datadir,"ozCoast_beaches_smartline"))

plot(AS_BEACHES_v)

state = "nsw"
image_source = "bing"

ress = 1.19
ncols = 512

tiles = vect(paste0(datadir,"coast_overlapping_tiles_512_119cm_",state))
tiles = tiles[perim(tiles) > 0]
crs(tiles) = "epsg:3857"
tiles_p = project(tiles,"epsg:4326")
download_tile_images = function(state = "vic",image_source = "bing",tiles_p_nth,ncols=512,ress=1.19){
    outfile = paste0(datadir,"aerial_beach_images/coast_overlapping_tiles_512_119cm/",state,"/",image_source,"_",state,"_image_",tiles_p_nth$FID,".tif")
    if(!file.exists(outfile)){
        ext_txt = paste(ext(buffer(tiles_p_nth,ress)))
        ext_txt = substr(ext_txt,5,nchar(ext_txt)-1)
        tile_ext = as.numeric(strsplit(ext_txt,",")[[1]])

         #download tile image from extent
         mp <- openmap(c(tile_ext[4],tile_ext[1]),
                           c(tile_ext[3],tile_ext[2]),zoom=17,type=image_source)
         r = rast(raster(mp))
         #output at ncols x ncols, e.g. 512 x 512
         rout = rast(xmin = xmin(r), ymin = ymin(r),xmax = xmax(r), ymax = ymax(r),ncol = ncols,nrow=ncols) 
         rout = resample(r,rout)  
         writeRaster(rout,outfile,overwrite = TRUE)
    } 
}

nth = 1
n = length(tiles_p)

s1 = Sys.time()
lapply((1:n),function(x) download_tile_images(state = state,image_source = "bing",tiles_p_nth = tiles_p[x],ncols=512,ress=1.19))
Sys.time()-s1

# the 3526th tile (FID 3691) didn't work, probably because it crosses wgs zones. 
#downloads ~ 22 tiles per min, so need 5.14 hrs for 6778 tiles

#8950 tiles for NSW takes 6.7hrs






