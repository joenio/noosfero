class Kalibro::Entities::MetricConfiguration < Kalibro::Entities::Entity

  attr_accessor :metric, :code, :weight, :aggregation_form, :range

  def metric=(value)
    if value.kind_of?(Hash)
      @metric = to_entity(value, Kalibro::Entities::CompoundMetric) if value.has_key?(:script)
      @metric = to_entity(value, Kalibro::Entities::NativeMetric) if value.has_key?(:origin)
    else
      @metric = value
    end
  end

  def range=(value)
    @range = to_entity_array(value, Kalibro::Entities::Range)
  end

  def ranges
    @range
  end

  def ranges=(ranges)
    @range = ranges
  end

end