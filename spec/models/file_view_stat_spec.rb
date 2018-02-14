RSpec.describe FileViewStat, type: :model do
  let(:file_id) { file.id }
  let(:user_id) { 123 }
  let(:date) { Time.current }
  let(:file_stat) { described_class.create(views: "25", date: date, file_id: file_id, user_id: user_id) }
  let(:file) { mock_model(FileSet, id: 99) }

  it "has attributes" do
    expect(file_stat).to respond_to(:views)
    expect(file_stat).to respond_to(:date)
    expect(file_stat).to respond_to(:file_id)
    expect(file_stat.file_id).to eq("99")
    expect(file_stat.date).to eq(date)
    expect(file_stat.views).to eq(25)
    expect(file_stat.user_id).to eq(user_id)
  end

  it 'has the correct dimension terms' do
    expect(described_class.dimension_terms).to be == ['date']
  end

  it 'has the correct metric terms' do
    expect(described_class.metric_terms).to be == ['pageviews']
  end

  it 'has the correct filters parameter' do
    expect(described_class.filters(file)).to be == 'ga:pagePath=~' + Rails.application.routes.url_helpers.polymorphic_path(file)
  end

  describe ".ga_statistic" do
    let(:start_date) { 2.days.ago }
    let(:reporting_service) { double }

    before do
      allow(Hyrax::Analytics).to receive(:profile).and_return([reporting_service], 'XXXXXXXXX')
    end

    context "when a profile is available" do
      it "calls the reporting service" do
        expect(reporting_service).to receive(:batch_get_reports)
        described_class.ga_statistics(start_date, file)
      end
    end

    context "when a profile not available" do
      it "returns an empty array" do
        allow(reporting_service).to receive(:batch_get_reports)
        expect(described_class.ga_statistics(start_date, file)).to be_empty
      end
    end
  end

  describe "#statistics" do
    let(:dates) do
      ldates = []
      4.downto(0) { |idx| ldates << (Time.zone.today - idx.day) }
      ldates
    end
    let(:date_strs) do
      dates.map { |date| date.strftime("%Y%m%d") }
    end

    let(:view_output) do
      [[statistic_date(dates[0]), 4], [statistic_date(dates[1]), 8], [statistic_date(dates[2]), 6], [statistic_date(dates[3]), 10]]
    end

    # This is what the data looks like that's returned from Google Analytics (GA) via ga_statistics
    # Due to the nature of querying GA, testing this data in an automated fashion is problematc.
    # Sample data structures were created by sending real events to GA from a test instance of
    # Scholarsphere.  The data below are essentially a "cut and paste" of query output.
    let(:sample_pageview_statistics) do
      [
        SpecStatistic.new(date: date_strs[0], pageviews: 4),
        SpecStatistic.new(date: date_strs[1], pageviews: 8),
        SpecStatistic.new(date: date_strs[2], pageviews: 6),
        SpecStatistic.new(date: date_strs[3], pageviews: 10)
      ]
    end

    describe "cache empty" do
      let(:stats) do
        expect(described_class).to receive(:ga_statistics).and_return(sample_pageview_statistics)
        described_class.statistics(file, Time.zone.today - 4.days, user_id)
      end

      it "includes cached ga data" do
        expect(stats.map(&:to_flot)).to include(*view_output)
      end

      it "caches data" do
        expect(stats.map(&:to_flot)).to include(*view_output)
        expect(stats.first.user_id).to eq user_id

        # at this point all data should be cached
        allow(described_class).to receive(:ga_statistics).with(Time.zone.today, file).and_raise("We should not call Google Analytics All data should be cached!")

        stats2 = described_class.statistics(file, Time.zone.today - 5.days)
        expect(stats2.map(&:to_flot)).to include(*view_output)
      end
    end

    describe "cache loaded" do
      let!(:file_view_stat) { described_class.create(date: (Time.zone.today - 5.days).to_datetime, file_id: file_id, views: "25") }

      let(:stats) do
        expect(described_class).to receive(:ga_statistics).and_return(sample_pageview_statistics)
        described_class.statistics(file, Time.zone.today - 5.days)
      end

      it "includes cached data" do
        expect(stats.map(&:to_flot)).to include([file_view_stat.date.to_i * 1000, file_view_stat.views], *view_output)
      end
    end
  end
end
