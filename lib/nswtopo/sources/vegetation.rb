module NSWTopo
  class VegetationSource
    include RasterRenderer

    def initialize(name, params)
      super name, { "embed" => true }.merge(params)
      @sourcedir = params["sourcedir"]
    end

    def get_raster(temp_dir)
      tif_path = temp_dir + "#{name}.tif"
      tfw_path = temp_dir + "#{name}.tfw"
      clut_path = temp_dir + "#{name}-clut.png"
      mask_path = temp_dir + "#{name}-mask.png"

      CONFIG.map.write_world_file tfw_path, resolution
      %x[convert -size #{dimensions.join ?x} canvas:white -type Grayscale -depth 8 "#{tif_path}"]

      [ *params["path"] ].map do |path|
        Pathname.new(path).expand_path(@sourcedir)
      end.map do |path|
        Pathname.glob path
      end.inject([], &:+).tap do |paths|
        raise BadLayerError.new("no vegetation data file specified") if paths.empty?
      end.group_by do |path|
        %x[gdalsrsinfo -o proj4 "#{path}"]
      end.values.each.with_index do |paths, index|
        src_path = temp_dir + "#{name}.#{index}.txt"
        vrt_path = temp_dir + "#{name}.#{index}.vrt"
        src_path.write paths.join(?\n)
        %x[gdalbuildvrt -input_file_list "#{src_path}" "#{vrt_path}"]
        %x[gdalwarp -t_srs "#{CONFIG.map.projection}" "#{vrt_path}" "#{tif_path}"]
      end

      low, high, factor, centre = { "low" => 0, "high" => 100, "factor" => 0.0, "centre" => 50 }.merge(params["contrast"] || {}).values_at("low", "high", "factor", "centre")
      %x[convert -size 1x256 canvas:black "#{clut_path}"]
      params["mapping"].map do |key, value|
        "j==#{key} ? %.5f : u" % (value < low ? 0.0 : value > high ? 1.0 : (value - low).to_f / (high - low))
      end.each do |fx|
        %x[mogrify -fx "#{fx}" "#{clut_path}"]
      end
      %x[mogrify -sigmoidal-contrast #{factor}x#{centre}% "#{clut_path}"]
      %x[convert "#{tif_path}" "#{clut_path}" -clut "#{mask_path}"]

      woody, nonwoody = params["colour"].values_at("woody", "non-woody")
      density = 0.01 * CONFIG.map.scale / resolution
      temp_dir.join(path.basename).tap do |raster_path|
        %x[convert -size #{dimensions.join ?x} -units PixelsPerCentimeter -density #{density} canvas:"#{nonwoody}" #{OP} "#{mask_path}" -background "#{woody}" -alpha Shape #{CP} -composite "#{raster_path}"]
      end
    end
  end
end
