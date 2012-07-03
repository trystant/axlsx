# encoding: UTF-8
module Axlsx
  # A Chart is the superclass for specific charts
  # @note Worksheet#add_chart is the recommended way to create charts for your worksheets.
  # @see README for examples
  class Chart


    # The 3D view properties for the chart
    attr_reader :view_3D
    alias :view3D :view_3D

    # A reference to the graphic frame that owns this chart
    # @return [GraphicFrame]
    attr_reader :graphic_frame

    # A collection of series objects that are applied to the chart
    # @return [SimpleTypedList]
    attr_reader :series

    # The type of series to use for this chart.
    # @return [Series]
    attr_reader :series_type

    #TODO data labels!
    #attr_reader :dLabls

    # The title object for the chart.
    # @return [Title]
    attr_reader :title

    # The style for the chart.
    # see ECMA Part 1 §21.2.2.196
    # @return [Integer]
    attr_reader :style

    # Show the legend in the chart
    # @return [Boolean]
    attr_reader :show_legend

    # Creates a new chart object
    # @param [GraphicalFrame] frame The frame that holds this chart.
    # @option options [Cell, String] title
    # @option options [Boolean] show_legend
    # @option options [Array|String|Cell] start_at The X, Y coordinates defining the top left corner of the chart.
    # @option options [Array|String|Cell] end_at The X, Y coordinates defining the bottom right corner of the chart.
    def initialize(frame, options={})
      @style = 18  
      @view_3D = nil
      @graphic_frame=frame
      @graphic_frame.anchor.drawing.worksheet.workbook.charts << self
      @series = SimpleTypedList.new Series
      @show_legend = true
      @series_type = Series
      @title = Title.new
      options.each do |o|
        self.send("#{o[0]}=", o[1]) if self.respond_to? "#{o[0]}="
      end
      start_at(*options[:start_at]) if options[:start_at]
      end_at(*options[:end_at]) if options[:end_at]
      yield self if block_given?
    end

    # The index of this chart in the workbooks charts collection
    # @return [Integer]
    def index
      @graphic_frame.anchor.drawing.worksheet.workbook.charts.index(self)
    end

    # The part name for this chart
    # @return [String]
    def pn
      "#{CHART_PN % (index+1)}"
    end

    # The title object for the chart.
    # @param [String, Cell] v
    # @return [Title]
    def title=(v)
      DataTypeValidator.validate "#{self.class}.title", [String, Cell], v
      if v.is_a?(String)
        @title.text = v
      elsif v.is_a?(Cell)
        @title.cell = v
      end
    end

    # Show the legend in the chart
    # @param [Boolean] v
    # @return [Boolean]
    def show_legend=(v) Axlsx::validate_boolean(v); @show_legend = v; end


    # The style for the chart.
    # see ECMA Part 1 §21.2.2.196
    # @param [Integer] v must be between 1 and 48
    def style=(v) DataTypeValidator.validate "Chart.style", Integer, v, lambda { |arg| arg >= 1 && arg <= 48 }; @style = v; end

    # backwards compatibility to allow chart.to and chart.from access to anchor markers
    # @note This will be disconinued in version 2.0.0. Please use the end_at method
    def to
      @graphic_frame.anchor.to
    end

    # backwards compatibility to allow chart.to and chart.from access to anchor markers
    # @note This will be disconinued in version 2.0.0. please use the start_at method
    def from
      @graphic_frame.anchor.from
    end

    # Adds a new series to the chart's series collection.
    # @return [Series]
    # @see Series
    def add_series(options={})
      @series_type.new(self, options)
      @series.last
    end

    # Serializes the object
    # @param [String] str
    # @return [String]
    def to_xml_string(str = '')
      str << '<?xml version="1.0" encoding="UTF-8"?>'
      str << '<c:chartSpace xmlns:c="' << XML_NS_C << '" xmlns:a="' << XML_NS_A << '" xmlns:r="' << XML_NS_R << '">'
      str << '<c:date1904 val="' << Axlsx::Workbook.date1904.to_s << '"/>'
      str << '<c:style val="' << style.to_s << '"/>'
      str << '<c:chart>'
      @title.to_xml_string str
      # do these need the c: namespace as well???
      str << '<c:autoTitleDeleted val="' << (@title == nil).to_s << '"/>'
      @view_3D.to_xml_string(str) if @view_3D
      str << '<c:floor><c:thickness val="0"/></c:floor>'
      str << '<c:sideWall><c:thickness val="0"/></c:sideWall>'
      str << '<c:backWall><c:thickness val="0"/></c:backWall>'
      str << '<c:plotArea>'
      str << '<c:layout/>'
      yield str if block_given?
      str << '</c:plotArea>'
      if @show_legend
        str << '<c:legend>'
        str << '<c:legendPos val="r"/>'
        str << '<c:layout/>'
        str << '<c:overlay val="0"/>'
        str << '</c:legend>'
      end
      str << '<c:plotVisOnly val="1"/>'
      str << '<c:dispBlanksAs val="zero"/>'
      str << '<c:showDLblsOverMax val="1"/>'
      str << '</c:chart>'
      str << '<c:printSettings>'
      str << '<c:headerFooter/>'
      str << '<c:pageMargins b="1.0" l="0.75" r="0.75" t="1.0" header="0.5" footer="0.5"/>'
      str << '<c:pageSetup/>'
      str << '</c:printSettings>'
      str << '</c:chartSpace>'
    end

    # This is a short cut method to set the start anchor position
    # If you need finer granularity in positioning use
    # graphic_frame.anchor.from.colOff / rowOff
    # @param [Integer] x The column
    # @param [Integer] y The row
    # @return [Marker]
    def start_at(x=0, y=0)
      x, y = *parse_coord_args(x, y)
      @graphic_frame.anchor.from.col = x
      @graphic_frame.anchor.from.row = y
    end

    # This is a short cut method to set the end anchor position
    # If you need finer granularity in positioning use
    # graphic_frame.anchor.to.colOff / rowOff
    # @param [Integer] x The column - default 10
    # @param [Integer] y The row - default 10
    # @return [Marker]
    def end_at(x=10, y=10)
      x, y = *parse_coord_args(x, y)
      @graphic_frame.anchor.to.col = x
      @graphic_frame.anchor.to.row = y
    end

    private

    def parse_coord_args(x, y=0)
      if x.is_a?(String)
        x, y = *Axlsx::name_to_indices(x)
      end
      if x.is_a?(Cell)
        x, y = *x.pos
      end
      if x.is_a?(Array)
        x, y = *x
      end
      [x, y]
    end

    def view_3D=(v) DataTypeValidator.validate "#{self.class}.view_3D", View3D, v; @view_3D = v; end
    alias :view3D= :view_3D=

  end
end
