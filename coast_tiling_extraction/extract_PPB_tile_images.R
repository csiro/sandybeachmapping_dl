require(terra)

rightn = function(x,n) substr(x, nchar(x)-n+1, nchar(x))


datadir = "/datasets/work/ev-coastal-ml/work/Beach_mapping/data/"
#datadir = "t:/work/Beach_mapping/data/"

imagedir = "/datasets/work/oa-ppbcha/source/DELWP_aerial_images/Port Phillip Historic Photography Project/"
#imagedir = "X:/source/DELWP_aerial_images/Port Phillip Historic Photography Project/"
res = 1.19
ncol = 512
state = ""

tiles = vect(paste0(datadir,"coast_overlapping_tiles_512_119cm/coast_overlapping_tiles_512_119cm_manual.shp"))
crs(tiles) = crs("epsg:3857")
OSMBeachShapes = vect(paste0(datadir,"OSM_overpass_student_beach_polygons/Shorts_beaches_CoastSat_OSMBeach_"
                             ,"vic",".geojson"))

#slow search for all the files
do_once = function(){
  tile_index = list.files(imagedir,pattern = "_tile-index.shp",recursive =TRUE,full.names = TRUE)
  write.csv(tile_index,file = paste0(datadir,"tile_index_PPB.csv"))
}

datasets = read.csv(paste0(datadir,"tile_index_PPB.csv"))[,2]
datasets_ss = sapply(datasets,function(x) strsplit(x,"/")[[1]])
datasets_df = data.frame(year = as.numeric(paste(datasets_ss[9,])),
                         folder = paste(datasets_ss[10,]),
                         metadata = datasets
                         )
vl = lapply(1:length(datasets),function(i) { y = vect(datasets_df$metadata[i]);
                                       names(y) = tolower(names(y));
                                       y$year = datasets_df$year[i];
                                       y$folder = datasets_df$folder[i]
                                       y$metadata = datasets_df$metadata[i];
                                       y})

v = vect(vl)

crs(v) = crs(vl[[1]])

aoi = tiles[tiles$FID == 2935]
aoi_p = project(aoi,v)

plot(v)
lines(aoi_p,col=3)

ix = which(relate(v,aoi_p,"intersects"))

infolders = paste0(imagedir,v[ix]$year,"/",v[ix]$folder,"/photography/")
j=1
vj = v[ix[j]]
infiles = list.files(infolders[j],pattern = vj$name,recursive =TRUE,full.names = TRUE)
infile= infiles[which(rightn(infiles,3) == "tif")]

historic_tile_images = function(state = "vic",image_source = "ppb",tiles_p_nth,ncols=512,ress=1.19,infiles){
    outfile = paste0(datadir,"aerial_beach_images/coast_overlapping_tiles_512_119cm/",state,"/image/",image_source,"_",state,"_image_",tiles_p_nth$FID,".tif")
         
    if(!file.exists(outfile)){
         if(length(infiles) > 1){
           rl = lapply(infiles,function(x) rast(x))
           r = do.call(terra::merge,rl)
         }
         if(length(infiles) == 1) r = rast(infiles)
         
         r = crop(r,tiles_p_nth)
         #output at ncols x ncols, e.g. 512 x 512
         rout = rast(xmin = xmin(r), ymin = ymin(r),xmax = xmax(r), ymax = ymax(r),ncol = ncols,nrow=ncols) 
         rout = resample(r,rout)  
         writeRaster(rout,outfile,overwrite = TRUE)
     }
}

aois = project(tiles[tiles$FID >= 2934 & tiles$FID <= 2937],v)
for(ai in 1:length(aois)){
  inx = which(relate(v,aois[ai],"intersects"))
  yrs = unique(v[inx]$year)
  vx = v[inx]
  for(yi in yrs){
     vxy = vx[vx$year == yi]
     infolder = paste0(imagedir,vxy$year,"/",vxy$folder,"/photography/")
     infile_l = list()
     for(vi in 1:length(vxy)){
       pat = strsplit(vxy$name[vi],"_")[[1]][1]
       infiles = list.files(infolder[1],pattern = pat,recursive =TRUE,full.names = TRUE)
       if(length(infiles) > 1) infile_l[vi] = infiles[which(rightn(infiles,3) == "tif")]
     }
     infiles = paste(infile_l)
     print(file.exists(infiles))
     if(length(infiles) > 0) historic_tile_images(state = "vic",image_source = paste0("ppb",vxy$year[1]),tiles_p_nth=aois[ai],ncols=512,ress=1.19,infiles=infiles)
   }
}




