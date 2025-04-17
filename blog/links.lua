function Link(elem)
  if string.sub(elem.target, 1, 1) ~= "#" then
    elem.attributes.target = "_blank"
  end
  return elem
end
