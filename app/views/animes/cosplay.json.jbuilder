json.content render(partial: 'cosplay_galleries/cosplay_gallery', collection: @collection, locals: { with_headline: true }, formats: :html)

if @add_postloader
  json.postloader render('blocks/postloader', filter: 'b-cosplay_gallery', url: @resource.cosplay_url(@page+1))
end
