import {cognitoUserPoolId, cognitoClientId, backendUrl, region} from "./config.js";

const Amplify = aws_amplify.default;
Amplify.configure({
	aws_appsync_graphqlEndpoint: backendUrl,
	aws_appsync_authenticationType: "AMAZON_COGNITO_USER_POOLS",
	Auth: {
		region,
		userPoolId: cognitoUserPoolId,
		userPoolWebClientId: cognitoClientId,
	},
});

const signin = async (username) => {
	try {
		await Amplify.Auth.signIn(username, "Password.01");
	}catch(e) {
		await Amplify.Auth.signUp({
			username,
			password: "Password.01",
		});
		await Amplify.Auth.signIn(username, "Password.01");
	}
}

const signinAsUser1 = () => signin("user1@example.com");
const signinAsUser2 = () => signin("user2@example.com");
const signinAsAdmin = () => signin("admin@example.com");

await signinAsAdmin();

const getAllUsers = async () => {
	const ListUsers = `query allUsers {
		allUsers {
			items {
				name
			}
		}
	}`;
	const allUsers = await Amplify.API.graphql({query: ListUsers})
	if (allUsers.errors) {
		throw new Error(allUsers);
	}
	return allUsers.data.allUsers;
}

const getMe = async () => {
	const Me = `query me {
		me {
			id
			name
			todos {
				items {
					name
					checked
					created
				}
			}
		}
	}`;
	const me = await Amplify.API.graphql({query: Me})
	if (me.errors) {
		throw new Error(me);
	}
	return me.data.me;
}

const addTodo = async (userId, name) => {
	const AddTodo = `mutation addTodo($userId: ID!, $name: String!) {
		addTodo(userId: $userId, name: $name) {
			name
			checked
			created
		}
	}`;
	const addTodo = await Amplify.API.graphql({query: AddTodo, variables: {userId, name}});
	if (addTodo.errors) {
		throw new Error(addTodo);
	}
	return addTodo.data.addTodo;
}


await signinAsUser1();
const me = await getMe();
const res = await addTodo(me.id, "test");

const subscribe = () => {
	const NewTodo = `subscription NewTodo {
		newTodo {
			name
			checked
			created
		}
	}`;
	return Amplify.API.graphql({query: NewTodo, variables: {}});
}
const subs = subscribe().subscribe({
	next: ({value}) => {
		console.log(value.data.newTodo);
	},
	error: (e) => console.error(e),
});
await new Promise((r) => setTimeout(r,2000))

await addTodo(me.id, "test2");
