require "./app"

require "rack/test_app"

app = Rack::TestApp.wrap(Rack::Lint.new(App))

response = app.post("/articles", multipart: {
  title: "Title",
  body:  "Body",
  image: File.open("files/image.jpg", "rb"),
})
puts response.body_text

article_id = response.body_json.fetch("id")

response = app.get("/articles/#{article_id}")
puts response.body_text

response = app.put("/articles/#{article_id}", multipart: {
  image: File.open("files/image.jpg", "rb"),
})

puts response.body_text

app.delete("/articles/#{article_id}")

puts Sequel::DATABASES.first[:articles].empty?
