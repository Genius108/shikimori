# frozen_string_literal: true

describe Collection::Update do
  subject { Collection::Update.call collection, params }

  let(:user) { create :user }
  let(:collection) { create :collection, :with_topics, user: user }

  context 'valid params' do
    let(:params) do
      {
        name: 'test collection',
        linked_ids: [anime_1.id, anime_2.id],
        linked_groups: %w[zz xx]
      }
    end
    let!(:collection_link_1) do
      create :collection_link, collection: collection, linked: anime_1
    end
    let!(:collection_link_2) do
      create :collection_link, collection: collection, linked: anime_3
    end
    let(:anime_1) { create :anime }
    let(:anime_2) { create :anime }
    let(:anime_3) { create :anime }

    before { subject }

    it do
      expect(collection.errors).to be_empty
      expect(collection.reload)
        .to have_attributes params.except(:linked_ids, :linked_groups)
      expect(collection.links).to have(2).items
      expect(collection.links.first).to have_attributes(
        linked_id: anime_1.id,
        linked_type: Anime.name,
        group: 'zz'
      )
      expect(collection.links.last).to have_attributes(
        linked_id: anime_2.id,
        linked_type: Anime.name,
        group: 'xx'
      )

      expect { collection_link_1.reload }.to raise_error ActiveRecord::RecordNotFound
      expect { collection_link_2.reload }.to raise_error ActiveRecord::RecordNotFound
    end
  end

  context 'invalid params' do
    let(:params) { { name: '' } }
    before { subject }

    it do
      expect(collection.errors).to be_present
      expect(collection.reload).not_to have_attributes params
    end
  end
end
