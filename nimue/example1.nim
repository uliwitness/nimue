on doThang appName, argument, arg2, arg3
    put "It works!"
    put " sometimes... "
    put appName
    put argument
    put arg3
    put "foo" into fooLocalVar
    put fooLocalVar
end doThang

function main
    local myLocalVar
    doThang "Hello, world!", 1, 42.5
end main
