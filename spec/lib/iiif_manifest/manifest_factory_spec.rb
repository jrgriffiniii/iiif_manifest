require 'spec_helper'

RSpec.describe IIIFManifest::ManifestFactory do
  subject { described_class.new(book_presenter) }

  let(:presenter_class) { Book }
  let(:book_presenter) { presenter_class.new('book-77') }

  before do
    class Book
      def initialize(id)
        @id = id
      end

      def description
        'a brief description'
      end

      def file_set_presenters
        []
      end

      def work_presenters
        []
      end

      def manifest_url
        "http://test.host/books/#{@id}/manifest"
      end

      def ranges
        @ranges ||=
          [
            ManifestRange.new(label: 'Table of Contents', ranges: [
                                ManifestRange.new(label: 'Chapter 1', file_set_presenters: [])
                              ])
          ]
      end
    end

    class ManifestRange
      attr_reader :label, :ranges, :file_set_presenters
      def initialize(label:, ranges: [], file_set_presenters: [])
        @label = label
        @ranges = ranges
        @file_set_presenters = file_set_presenters
      end
    end

    class DisplayImagePresenter
      attr_reader :id, :label
      def initialize(id: 'test-22', label: 'Page 1')
        @id = id
        @label = label
      end

      def to_s
        label
      end

      def display_image
        IIIFManifest::DisplayImage.new(id, width: 100, height: 100, format: 'image/jpeg')
      end
    end
  end

  after do
    Object.send(:remove_const, :DisplayImagePresenter)
    Object.send(:remove_const, :Book)
  end

  describe '#to_h' do
    let(:result) { subject.to_h }
    let(:json_result) { JSON.parse(subject.to_h.to_json) }

    it 'has a label' do
      expect(result.label).to eq book_presenter.to_s
    end
    it 'has an ID' do
      expect(result['@id']).to eq 'http://test.host/books/book-77/manifest'
    end

    context 'when there are no files' do
      it 'returns no sequences' do
        expect(result['sequences']).to eq nil
      end
    end

    context 'when there is a fileset' do
      let(:file_presenter) { DisplayImagePresenter.new }

      it 'returns a sequence' do
        allow(IIIFManifest::ManifestBuilder::CanvasBuilder).to receive(:new).and_call_original
        allow(book_presenter).to receive(:file_set_presenters).and_return([file_presenter])

        result

        expect(IIIFManifest::ManifestBuilder::CanvasBuilder).to have_received(:new)
          .exactly(1).times.with(file_presenter, anything, anything)
      end
      it 'builds a structure if it can' do
        allow(book_presenter).to receive(:file_set_presenters).and_return([file_presenter])
        allow(book_presenter.ranges[0].ranges[0]).to receive(:file_set_presenters).and_return([file_presenter])

        expect(result['structures'].length).to eq 2
        structure = result['structures'].first
        expect(structure['label']).to eq 'Table of Contents'
        expect(structure['viewingHint']).to eq 'top'
        expect(structure['canvases']).to be_blank
        expect(structure['ranges'].length).to eq 1
        expect(structure['ranges'][0]).not_to eq structure['@id']

        sub_range = result['structures'].last
        expect(sub_range['ranges']).to be_blank
        expect(sub_range['canvases'].length).to eq 1
      end
    end

    context 'when there is a no sequence_rendering method' do
      let(:file_presenter) { DisplayImagePresenter.new }

      it 'does not have a rendering on the sequence' do
        allow(IIIFManifest::ManifestBuilder::CanvasBuilder).to receive(:new).and_call_original
        allow(book_presenter).to receive(:file_set_presenters).and_return([file_presenter])
        expect(result['sequences'][0]['rendering']).to eq []
      end
    end

    context 'when there is a sequence_rendering method' do
      let(:file_presenter) { DisplayImagePresenter.new }

      before do
        class Book
          def initialize(id)
            @id = id
          end

          def description
            'a brief description'
          end

          def file_set_presenters
            []
          end

          def work_presenters
            []
          end

          def manifest_url
            "http://test.host/books/#{@id}/manifest"
          end

          def sequence_rendering
            [{ '@id' => 'http://test.host/file_set/id/download',
               'format' => 'application/pdf',
               'label' => 'Download' }]
          end
        end
      end

      it 'has a rendering on the sequence' do
        allow(IIIFManifest::ManifestBuilder::CanvasBuilder).to receive(:new).and_call_original
        allow(book_presenter).to receive(:file_set_presenters).and_return([file_presenter])

        expect(result['sequences'][0]['rendering']).to eq [{
          '@id' => 'http://test.host/file_set/id/download', 'format' => 'application/pdf', 'label' => 'Download'
        }]
      end
    end

    context 'when there is no manifest_metadata method' do
      let(:file_presenter) { DisplayImagePresenter.new }

      it 'does not have a metadata element' do
        allow(IIIFManifest::ManifestBuilder::CanvasBuilder).to receive(:new).and_call_original
        allow(book_presenter).to receive(:file_set_presenters).and_return([file_presenter])
        expect(result['metadata']).to eq nil
      end
    end

    context 'when there is a manifest_metadata method' do
      let(:metadata) { [{ 'label' => 'Title', 'value' => 'Title of the Item' }] }

      it 'has metadata' do
        allow(book_presenter).to receive(:manifest_metadata).and_return(metadata)
        expect(result['metadata'][0]['label']).to eq 'Title'
        expect(result['metadata'][0]['value']).to eq 'Title of the Item'
      end
    end

    context 'when there is a manifest_metadata method with invalid data' do
      let(:metadata) { 'invalid data' }

      it 'has no metadata' do
        allow(book_presenter).to receive(:manifest_metadata).and_return(metadata)
        expect(result['metadata']).to eq nil
      end
    end

    context 'when there is no search_service method' do
      let(:file_presenter) { DisplayImagePresenter.new }

      it 'does not have a service element' do
        allow(IIIFManifest::ManifestBuilder::CanvasBuilder).to receive(:new).and_call_original
        allow(book_presenter).to receive(:file_set_presenters).and_return([file_presenter])
        expect(result['service']).to eq nil
      end
    end

    context 'when there is a search_service method' do
      let(:search_service) { 'http://test.host/books/book-77/search' }

      it 'has a service element with the correct profile, @id and without an embedded service element' do
        allow(book_presenter).to receive(:search_service).and_return(search_service)
        expect(result['service'][0]['profile']).to eq 'http://iiif.io/api/search/0/search'
        expect(result['service'][0]['@id']).to eq 'http://test.host/books/book-77/search'
        expect(result['service'][0]['service']).to eq nil
      end
    end

    context 'when there is a search_service method that returns nil' do
      let(:search_service) { '' }

      it 'has no service' do
        allow(book_presenter).to receive(:search_service).and_return(search_service)
        expect(result['service']).to eq nil
      end
    end

    context 'when there is an autocomplete_service method' do
      let(:search_service) { 'http://test.host/books/book-77/search' }
      let(:autocomplete_service) { 'http://test.host/books/book-77/autocomplete' }

      it 'has a service element within the first service containing @id and profile for the autocomplete service' do
        allow(book_presenter).to receive(:search_service).and_return(search_service)
        allow(book_presenter).to receive(:autocomplete_service).and_return(autocomplete_service)
        expect(result['service'][0]['service']['@id']).to eq 'http://test.host/books/book-77/autocomplete'
        expect(result['service'][0]['service']['profile']).to eq 'http://iiif.io/api/search/0/autocomplete'
      end
    end

    context 'when there is no autocomplete_service method' do
      let(:search_service) { 'http://test.host/books/book-77/search' }

      it 'has a service element within the first service' do
        allow(book_presenter).to receive(:search_service).and_return(search_service)
        expect(result['service'][0]['service']).to eq nil
      end
    end

    context 'when there is an autocomplete_service method but no search service' do
      let(:autocomplete_service) { 'http://test.host/books/book-77/autocomplete' }

      it 'has a service element within the first service' do
        allow(book_presenter).to receive(:autocomplete_service).and_return(autocomplete_service)
        expect(result['service']).to eq nil
      end
    end

    context 'when there are child works' do
      let(:child_work_presenter) { presenter_class.new('test2') }

      before do
        allow(book_presenter).to receive(:work_presenters).and_return([child_work_presenter])
      end
      it 'returns a IIIF Collection' do
        expect(result['@type']).to eq 'sc:Collection'
      end
      it "doesn't build sequences" do
        expect(result['sequences']).to eq nil
      end
      it 'has a multi-part viewing hint' do
        expect(json_result['viewingHint']).to eq 'multi-part'
      end
      it 'builds child manifests' do
        expect(result['manifests'].length).to eq 1
        first_child = result['manifests'].first
        expect(first_child['@id']).to eq 'http://test.host/books/test2/manifest'
        expect(first_child['@type']).to eq 'sc:Manifest'
        expect(first_child['label']).to eq child_work_presenter.to_s
      end
    end

    context 'when there are child works AND files' do
      let(:child_work_presenter) { presenter_class.new('test-99') }
      let(:file_presenter) { DisplayImagePresenter.new }
      let(:file_presenter2) { DisplayImagePresenter.new }

      before do
        allow(book_presenter).to receive(:work_presenters).and_return([child_work_presenter])
        allow(book_presenter).to receive(:file_set_presenters).and_return([file_presenter])
        allow(child_work_presenter).to receive(:file_set_presenters).and_return([file_presenter2])
      end
      it 'returns a IIIF Manifest' do
        expect(result['@type']).to eq 'sc:Manifest'
      end
      it "doesn't build manifests" do
        expect(result['manifests']).to eq nil
      end
      it 'builds sequences from all the child file sets' do
        expect(result['sequences'].first['canvases'].length).to eq 2
      end
    end

    context 'when there are child works AMD when the work identifies itself as a sammelband' do
      let(:child_work_presenter) { presenter_class.new('test-99') }
      let(:file_presenter) { DisplayImagePresenter.new }

      before do
        allow(book_presenter).to receive(:sammelband?).and_return(true)
        allow(book_presenter).to receive(:work_presenters).and_return([child_work_presenter])
        allow(child_work_presenter).to receive(:file_set_presenters).and_return([file_presenter])
      end
      it 'returns a IIIF Manifest' do
        expect(result['@type']).to eq 'sc:Manifest'
      end
      it "doesn't build manifests" do
        expect(result['manifests']).to eq nil
      end
      it 'builds sequences from all the child file sets' do
        expect(result['sequences'].first['canvases'].length).to eq 1
      end
    end

    context 'when there is no viewing_direction method' do
      it 'does not have a viewingDirection element' do
        expect(result['viewingDirection']).to eq nil
      end
    end

    context 'when there is a viewing_direction method' do
      it 'has a viewingDirection' do
        allow(book_presenter).to receive(:viewing_direction).and_return('right-to-left')
        expect(result.viewingDirection).to eq 'right-to-left'
      end
    end

    context 'sanitizing HTML markup' do
      let(:b_tag) { "<b>Samvera</b>" }
      let(:escaped_b_tag) { "&lt;b&gt;Samvera&lt;/b&gt;" }
      let(:illegal_img_tag) { "<img src=xx:x onerror=eval('\x61ler\x74(1)') />" }
      let(:pruned_img_tag) { "<img>" }
      let(:structure_with_html) do
        [
          ManifestRange.new(label: '<b>Table of Contents</b>', ranges: [
                              ManifestRange.new(label: '<span>Chapter 1</span>', file_set_presenters: [])
                            ])
        ]
      end
      let(:metadata_with_html) do
        [
          { "label" => "Title", "value" => illegal_img_tag },
          { "label" => "Creator", "value" => b_tag }
        ]
      end

      it 'escapes all HTML markup from label' do
        allow(book_presenter).to receive(:to_s).and_return(b_tag)
        expect(result.label).to eq escaped_b_tag
      end

      it 'escapes all HTML markup from canvas labels' do
        file_presenter = DisplayImagePresenter.new(label: b_tag)
        allow(book_presenter).to receive(:file_set_presenters).and_return([file_presenter])
        sequence = result['sequences'].first
        canvas = sequence['canvases'].first
        expect(canvas['label']).to eq escaped_b_tag
      end

      it 'escapes all HTML markup from structure labels' do
        file_presenter = DisplayImagePresenter.new(label: b_tag)
        allow(book_presenter).to receive(:file_set_presenters).and_return([file_presenter])
        allow(book_presenter).to receive(:ranges).and_return(structure_with_html)
        allow(book_presenter.ranges[0].ranges[0]).to receive(:file_set_presenters).and_return([file_presenter])
        structure = result['structures'].first
        expect(structure['label']).to eq '&lt;b&gt;Table of Contents&lt;/b&gt;'
        sub_range = result['structures'].last
        expect(sub_range['label']).to eq '&lt;span&gt;Chapter 1&lt;/span&gt;'
      end

      it 'prunes unsafe HTML markup from description' do
        allow(book_presenter).to receive(:description).and_return(illegal_img_tag)
        expect(result.label).to eq pruned_img_tag
      end

      it 'prunes unsafe HTML markup from metadata' do
        allow(book_presenter).to receive(:manifest_metadata).and_return(metadata_with_html)
        expect(result["metadata"][0]["value"]).to eq pruned_img_tag
        expect(result["metadata"][1]["value"]).to eq b_tag
      end
    end
  end
end
