##################################################
# FILE UTILITIES
# Author: Suk Yee Yong
##################################################

import geopandas as gpd
import numpy as np
import pandas as pd
import random
import rasterio
from rasterio.features import shapes
from shapely.geometry import shape
import yaml


def get_config(config_path: str='config/config.yaml') -> dict:
    """Return configs from yaml file"""
    print(f"Load config file >> {config_path}")
    with open(config_path, 'r') as f:
        return yaml.safe_load(f)


def set_seed(seed: int=42):
    """Set random seed for reproducibility"""
    np.random.seed(seed)
    random.seed(seed)
    try:
        import torch
        torch.manual_seed(seed)
        torch.use_deterministic_algorithms(True)
        torch.backends.cudnn.benchmark = False
    except ImportError:
        pass


def write_geotiff(data, save_filepath, profile_tif_filepath=None, profile_params=dict()):
    """
    Write GeoTiff to file
    
    Parameters
    ----------
        data: Data
        save_filepath: Save file path
        profile_tif_filepath: File path of TIF file to copy it's profile to new TIF file. Default is None without using any reference profile from another TIF file.
        profile_params: dict of metadata keyword arguments which overwrites those in profile_tif_filepath
    
    Returns
    ----------
        profile: Metadata keyword arguments
    """
    profile = {'driver': 'GTiff', 'dtype': rasterio.float32, 'count': 1}
    if profile_tif_filepath is not None:
        # print(f"\tGeoTiff profile from >> {profile_tif_filepath} ...")
        with rasterio.open(profile_tif_filepath) as dstm:
            profile = dstm.profile
    if profile_params:
        profile = profile | profile_params
    with rasterio.open(save_filepath, mode='w', **profile) as dst:
        dst.write(data, 1)
    # print(f"\tSaved GeoTiff >> {save_filepath}")
    return profile


def write_shapefile(list_tiffiles, save_filepath='polygons.shp.zip'):
    """
    Write list of raster images to shapefile
    
    Parameters
    ----------
        list_tiffiles: List of TIF file
        save_filepath: Save file path
    
    Returns
    ----------
        gdf: GeoDataFrame of shapefile
    """
    gdfs = []
    for i, tif_file in enumerate(list_tiffiles):
        with rasterio.open(tif_file) as src:
            image = src.read(1)
            if not i: src_crs = src.crs # Set same CRS
        gen_shapes = shapes(image, mask=(image==1), transform=src.transform)
        geoms = [shape(shp) for shp, _ in gen_shapes]
        gdfs.append(gpd.GeoDataFrame(geometry=geoms, crs=src_crs))
    gdf = pd.concat(gdfs).dissolve()
    gdf.to_file(filename=save_filepath, driver='ESRI Shapefile')
    print(f"\tSaved shapefile >> {save_filepath}")
    return gdf

