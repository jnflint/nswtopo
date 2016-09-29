module NSWTopo
  module VectorRenderer
    def render_svg(xml, map)
      unless map.rotation.zero?
        w, h = map.bounds.map { |bound| 1000.0 * (bound.max - bound.min) / map.scale }
        t = Math::tan(map.rotation * Math::PI / 180.0)
        d = (t * t - 1) * Math::sqrt(t * t + 1)
        if t >= 0
          y = (t * (h * t - w) / d).abs
          x = (t * y).abs
        else
          x = -(t * (h + w * t) / d).abs
          y = -(t * x).abs
        end
        transform = "translate(#{x} #{-y}) rotate(#{map.rotation})"
      end
      
      groups = { }
      draw(map) do |element, sublayer, defs|
        group = groups[sublayer] ||= yield(sublayer).tap do |group|
          group.add_attributes("transform" => transform) if group && transform
        end
        (defs ? xml.elements["//svg/defs"] : group).add_element(element) if group
      end
    end
  end
end