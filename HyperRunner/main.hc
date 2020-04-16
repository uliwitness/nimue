function quoted str
    return "'" & str & "'"
end quoted

on startup
    output "Main script running." && quoted("yay")
end startup
