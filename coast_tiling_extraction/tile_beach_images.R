#Student beach mapping shapes for training of ML beach image identification

#install.packages(c("OpenStreetMap","terra","raster","sf","sp"))
#It follows the order of a path of line segments along the coast of a Australian state (e.g. VIC), that was converted to points (start and end points where line segments touch), and then each point gets a Feature ID. A buffer is made around each point, then the square extent of this circle is converted into a polygon which makes the tile.
require(terra)

require(smoothr)

datadir = "/datasets/work/ev-coastal-ml/work/Beach_mapping/data/"

#This dataset has the query points of every beach in Australia
AS_BEACHES_v = vect(paste0(datadir,"ozCoast_beaches_smartline"))

plot(AS_BEACHES_v)


coastline = vect(paste0("/home/ogr013/notebooks/cihinundation/data/LGA_2023_AUST_GDA2020_coastline"))

#
epsgs = "epsg:3857"
#epsgs = "epsg:7842"

coastline_p = project(coastline,epsgs)

state = "nsw"
image_source = "bing"

OSMBeachShapes = vect(paste0(datadir,"OSM_overpass_student_beach_polygons/Shorts_beaches_CoastSat_OSMBeach_"
                                ,state,".geojson"))

OSMBeachShapes_p = project(OSMBeachShapes,epsgs)

state_extent = ext(buffer(OSMBeachShapes_p,1000))

res = 1.19
ncol = 512
r = rast(state_extent,resolution = res*ncol)
v = as.polygons(r)

cl = crop(coastline_p,r)

cls = smooth(simplifyGeom(cl,ceiling(res*ncol/6)),method = "densify",max_distance = ceiling(res*ncol*0.9))

unlink( paste0(datadir,"coast_s_",state), recursive=TRUE)
writeVector(cls,file = paste0(datadir,"coast_s_",state))

clsb = buffer(cls,ceiling(res*ncol*1.1))
rc = rasterize(x=clsb,y=r)
ix = which(!is.na(values(rc)))

unlink( paste0(datadir,"coast_nonOverlapping_tiles_",ncol,"_",round(res*100),"cm_",state), recursive=TRUE)
writeVector(v[ix],file = paste0(datadir,"coast_nonOverlapping_tiles_",ncol,"_",round(res*100),"cm_",state))


clp = as.points(cls)

unlink( paste0(datadir,"coast_p_",state), recursive=TRUE)
writeVector(clp,file = paste0(datadir,"coast_p_",state))

clsc = buffer(clp,ceiling(res*ncol/2))

clscel = lapply(1:length(clsc),function(x) as.polygons(ext(clsc[x])))

clsce = vect(clscel)

selfOverlapN = relate(clsce,relation="intersects")

ns = dim(selfOverlapN)[1]
rs = sapply(1:ns,function(x) sum(selfOverlapN[x,][1:x]))

thr = 5
keep = which(rs <= thr)
dont = which(rs > thr)

unlink( paste0(datadir,"coast_overlapping_tiles_",ncol,"_",round(res*100),"cm_",state), recursive=TRUE)
writeVector(clsce[keep],file = paste0(datadir,"coast_overlapping_tiles_",ncol,"_",round(res*100),"cm_",state))







