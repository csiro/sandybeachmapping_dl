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

state = "vic"
image_source = "bing"
download_images = function(state = "vic",image_source = "bing"){
    OSMBeachShapes = vect(paste0(datadir,"OSM_overpass_student_beach_polygons/Shorts_beaches_CoastSat_OSMBeach_"
                                ,state,".geojson"))

    areas = expanse(OSMBeachShapes)

    runorder = order(areas,decreasing=FALSE) # loop from smallest to largest

    for(nth in runorder){
        ext_txt = paste(ext(OSMBeachShapes[nth]))
        ext_txt = substr(ext_txt,5,nchar(ext_txt)-1)
        OSM_beach_ext = as.numeric(strsplit(ext_txt,",")[[1]])

        #plot(OSMBeachShapes[nth])

        

        mp <- openmap(c(OSM_beach_ext[4],OSM_beach_ext[1]),
                           c(OSM_beach_ext[3],OSM_beach_ext[2]),zoom=18,type=image_source)

        
        xmax(r) - (xmin(r)+res(r)[1]*ncol(r))
        ymax(r) - (ymin(r)+res(r)[2]*nrow(r))
        r = rast(raster(mp))
        
        #tile the results into 256x256 images for the ML
        square_tile_size = 256
        ncol2 = ceiling(ncol(r)/(square_tile_size))
        nrow2 = ceiling(nrow(r)/(square_tile_size))
        
        #buid a new raster so that makeTiles works
        tr = rast(xmin = xmin(r), ymin = ymin(r), 
                  xmax = xmin(r)+res(r)[1]*square_tile_size*ncol2, ymax = ymin(r)+res(r)[2]*square_tile_size*nrow2,
                  ncol = ncol2,nrow = nrow2,crs = r)
        
        re = extend(r,tr)
        
        #mask the image
        OSMbsp = project(OSMBeachShapes[nth],re)
        rem = mask(re,OSMbsp)
        
        osmid = OSMBeachShapes$osm_id[nth]
        outfile = paste0(datadir,"aerial_beach_images/",image_source,"_",state,"_image_",osmid,"_.tif")
        f = makeTiles(re,tr,outfile,extend=FALSE,overwrite=TRUE)
        
        outfileMask = paste0(datadir,"aerial_beach_images/",image_source,"_",state,"_masked_",osmid,"_.tif")
        fm = makeTiles(rem,tr,outfileMask,extend=FALSE,overwrite=TRUE)
        
        
        #writeRaster(r,outfile,overwrite = TRUE)
    }
}

download_images(state = "vic",image_source = "bing")

setwd("/datasets/work/ev-coastal-ml/work/Beach_mapping/data/aerial_beach_images")
af = list.files()

afm = (which(grepl("masked", af, fixed = TRUE)))
afi = (which(grepl("image", af, fixed = TRUE)))

afmOSMid = paste(sapply(af[afm],function(x) strsplit(x,"_masked_")[[1]][2]))
afiOSMid = paste(sapply(af[afi],function(x) strsplit(x,"_image_")[[1]][2]))

setdiff(afmOSMid,afiOSMid)







